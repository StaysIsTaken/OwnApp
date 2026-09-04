import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/utils/snack.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:productivity/dataservice/biometric_service.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/widgets/server_dialog.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/ai_model.dart';
import 'package:productivity/dataservice/ai_service.dart';
import 'package:productivity/dataservice/ai_settings_service.dart';
import 'package:productivity/dataservice/local_notification_manager.dart';
import 'package:productivity/widgets/settings_tile.dart';

import 'package:productivity/provider/settings_provider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends BasePage {
  const SettingsPage({super.key}) : super(title: 'Einstellungen');

  @override
  Widget buildBody(BuildContext context) => const _SettingsBody();
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  bool _biometrieVerfuegbar = false;
  bool _biometrieAn = false;
  String _biometrieName = 'Face ID';

  Future<void> _biometrieStandLaden() async {
    final verfuegbar = await BiometricService.verfuegbar();
    if (!verfuegbar || !mounted) return;
    final name = await BiometricService.bezeichnung();
    final gemerkt = await BiometricService.gemerkt();
    if (!mounted) return;
    setState(() {
      _biometrieVerfuegbar = true;
      _biometrieName = name;
      _biometrieAn = gemerkt != null;
    });
  }

  /// Einschalten heisst: Passwort abfragen und hinterlegen. Es steht nirgends
  /// im Klartext herum, wo man es sonst herbekommen koennte – deshalb muss
  /// der Nutzer es hier noch einmal eingeben.
  Future<void> _biometrieUmschalten(bool an) async {
    if (!an) {
      await BiometricService.vergessen();
      if (mounted) setState(() => _biometrieAn = false);
      return;
    }

    final nutzer = context.read<UserProvider>().user;
    if (nutzer == null) return;

    final passwort = await showDialog<String>(
      context: context,
      builder: (_) => _PasswortAbfrage(name: _biometrieName),
    );
    if (passwort == null || passwort.isEmpty) return;

    // Erst pruefen, ob das Passwort ueberhaupt stimmt – sonst laege ein
    // falsches in der Keychain und die Anmeldung schluege jedes Mal fehl,
    // ohne dass jemand den Grund saehe.
    try {
      await LoginService.login(username: nutzer.username, password: passwort);
    } on DioException {
      if (mounted) showErrorSnack('Das Passwort stimmt nicht.');
      return;
    }

    await BiometricService.merken(
        benutzername: nutzer.username, passwort: passwort);
    if (mounted) {
      setState(() => _biometrieAn = true);
      showSnack('$_biometrieName eingerichtet');
    }
  }

  /// Serveradresse aendern. Die Anmeldung gilt beim alten Server, deshalb
  /// meldet der Dialog ab – die App landet danach beim Login.
  Future<void> _serverAendern() async {
    final geaendert = await showDialog<bool>(
      context: context,
      builder: (_) => const ServerDialog(),
    );
    if (geaendert == true && mounted) {
      setState(() {});
      context.read<UserProvider>().logout();
    }
  }

  bool _notifEnabled = true;
  bool _notifChat = true;
  bool _notifTasks = true;
  bool _notifPantry = true;
  bool _notifPlanner = true;
  bool _notifPermitted = true;
  bool _loaded = false;
  List<AIModel> _aiModels = [];
  bool _aiModelsLoading = true;

  // KI-Anbieter-Profile (serverseitig, pro User; genau eines aktiv)
  List<AiProvider> _providers = [];
  bool _providersLoading = true;
  List<String> _activeModels = [];
  bool _loadingActiveModels = false;

  final TextEditingController _weatherCityCtrl = TextEditingController();

  @override
  void dispose() {
    _weatherCityCtrl.dispose();
    super.dispose();
  }

  AiProvider? get _activeProvider {
    for (final p in _providers) {
      if (p.isActive) return p;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadNotifSettings();
    _loadAIModels();
    _loadProviders();
    _biometrieStandLaden();
  }

  String _providerLabel(String p) {
    switch (p) {
      case 'ollama':
        return 'Lokal (Ollama)';
      case 'openrouter':
        return 'OpenRouter';
      case 'gemini':
        return 'Google Gemini';
      case 'mistral':
        return 'Mistral';
      default:
        return 'Eigener Anbieter';
    }
  }

  Future<void> _loadProviders() async {
    try {
      final list = await AiSettingsService.list();
      if (!mounted) return;
      setState(() {
        _providers = list;
        _providersLoading = false;
        _activeModels = [];
      });
    } catch (e) {
      if (mounted) setState(() => _providersLoading = false);
    }
  }

  Future<void> _activate(AiProvider p) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AiSettingsService.activate(p.id);
      await _loadProviders();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _deleteProvider(AiProvider p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anbieter löschen?'),
        content: Text('„${p.name}" wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AiSettingsService.delete(p.id);
      await _loadProviders();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _loadActiveModels() async {
    final p = _activeProvider;
    if (p == null) return;
    setState(() => _loadingActiveModels = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final models = await AiSettingsService.listModels(p.id);
      if (!mounted) return;
      setState(() {
        _activeModels = models;
        _loadingActiveModels = false;
      });
      if (models.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Keine Modelle gefunden.')));
      }
    } catch (e) {
      if (mounted) setState(() => _loadingActiveModels = false);
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _setActiveModel(String model) async {
    final p = _activeProvider;
    if (p == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AiSettingsService.update(p.id, model: model);
      await _loadProviders();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _openProviderDialog([AiProvider? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final keyCtrl = TextEditingController();
    final baseUrlCtrl = TextEditingController(text: existing?.baseUrl ?? '');
    String provider = existing?.provider ?? 'ollama';
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null
              ? 'Anbieter hinzufügen'
              : 'Anbieter bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Name (frei wählbar)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: provider,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Typ'),
                  items: const [
                    DropdownMenuItem(
                        value: 'ollama', child: Text('Lokal (Ollama)')),
                    DropdownMenuItem(
                        value: 'openrouter', child: Text('OpenRouter')),
                    DropdownMenuItem(
                        value: 'gemini', child: Text('Google Gemini')),
                    DropdownMenuItem(value: 'mistral', child: Text('Mistral')),
                    DropdownMenuItem(
                        value: 'custom',
                        child: Text('Eigener (OpenAI-kompatibel)')),
                  ],
                  onChanged: (v) => setLocal(() => provider = v ?? 'ollama'),
                ),
                if (provider != 'ollama') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'API-Key',
                      hintText: (existing?.hasKey ?? false)
                          ? '•••••••• (gespeichert – zum Ändern neu eingeben)'
                          : 'API-Key einfügen',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: baseUrlCtrl,
                    decoration: InputDecoration(
                      labelText: provider == 'custom'
                          ? 'Base-URL (erforderlich)'
                          : 'Base-URL (optional)',
                      hintText: provider == 'custom'
                          ? 'z.B. https://api.mistral.ai/v1'
                          : 'leer = Standard des Anbieters',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Speichern')),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final name =
        nameCtrl.text.trim().isEmpty ? provider : nameCtrl.text.trim();
    try {
      if (existing == null) {
        await AiSettingsService.create(
          name: name,
          provider: provider,
          baseUrl: baseUrlCtrl.text.trim(),
          apiKey: keyCtrl.text.isNotEmpty ? keyCtrl.text : null,
        );
      } else {
        await AiSettingsService.update(
          existing.id,
          name: name,
          provider: provider,
          baseUrl: baseUrlCtrl.text.trim(),
          apiKey: keyCtrl.text.isNotEmpty ? keyCtrl.text : null,
        );
      }
      await _loadProviders();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _loadAIModels() async {
    try {
      final models = await AIService.getAvailableModels();
      if (mounted) {
        setState(() {
          _aiModels = models;
          _aiModelsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiModels = [];
          _aiModelsLoading = false;
        });
      }
    }
  }

  Future<void> _loadNotifSettings() async {
    final mgr = LocalNotificationManager();
    final enabled = await mgr.isEnabled();
    final chat = await mgr.isCategoryEnabled(LocalNotificationManager.prefChat);
    final tasks =
        await mgr.isCategoryEnabled(LocalNotificationManager.prefTasks);
    final pantry =
        await mgr.isCategoryEnabled(LocalNotificationManager.prefPantry);
    final planner =
        await mgr.isCategoryEnabled(LocalNotificationManager.prefPlanner);
    final permitted = await mgr.areNotificationsEnabled();

    if (!mounted) return;
    setState(() {
      _notifEnabled = enabled;
      _notifChat = chat;
      _notifTasks = tasks;
      _notifPantry = pantry;
      _notifPlanner = planner;
      _notifPermitted = permitted;
      _loaded = true;
    });
  }

  Future<void> _setMaster(bool value) async {
    setState(() => _notifEnabled = value);
    await LocalNotificationManager().setEnabled(value);
  }

  Future<void> _setCategory(String key, bool value) async {
    setState(() {
      if (key == LocalNotificationManager.prefChat) _notifChat = value;
      if (key == LocalNotificationManager.prefTasks) _notifTasks = value;
      if (key == LocalNotificationManager.prefPantry) _notifPantry = value;
      if (key == LocalNotificationManager.prefPlanner) _notifPlanner = value;
    });
    await LocalNotificationManager().setCategoryEnabled(key, value);
  }

  Future<void> _requestPermissions() async {
    final granted = await LocalNotificationManager().requestPermissions();
    if (!mounted) return;
    setState(() => _notifPermitted = granted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(granted
            ? 'Benachrichtigungen aktiviert ✅'
            : 'Berechtigung verweigert. Bitte in den Systemeinstellungen erlauben.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = Provider.of<SettingsProvider>(context);

    // Stadt-Feld einmalig befüllen, sobald die Prefs geladen sind.
    if (_weatherCityCtrl.text.isEmpty && settings.weatherCity.isNotEmpty) {
      _weatherCityCtrl.text = settings.weatherCity;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Server ──
        // Ganz oben, weil fast alles davon abhaengt: laeuft die App gegen
        // den falschen Server, ist jede andere Einstellung nebensaechlich.
        _SectionTitle('Server'),
        Card(
          child: ListTile(
            leading: Icon(Icons.dns_outlined, color: colors.primary),
            title: const Text('API-Adresse'),
            subtitle: Text(ApiClient.baseUrl),
            trailing: const Icon(Icons.chevron_right),
            onTap: _serverAendern,
          ),
        ),
        const SizedBox(height: 16),

        // ── Anmeldung ──
        if (_biometrieVerfuegbar) ...[
          _SectionTitle('Anmeldung'),
          Card(
            child: SwitchListTile(
              secondary: Icon(Icons.fingerprint, color: colors.primary),
              title: Text('Mit $_biometrieName anmelden'),
              subtitle: Text(
                _biometrieAn
                    ? 'Dein Passwort liegt verschlüsselt auf diesem Gerät und '
                      'wird nur nach erfolgreicher Prüfung verwendet.'
                    : 'Passwort einmal verschlüsselt hinterlegen, danach '
                      'genügt $_biometrieName.',
                style: const TextStyle(fontSize: 12),
              ),
              value: _biometrieAn,
              onChanged: _biometrieUmschalten,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Allgemein ──
        _SectionTitle('Allgemein'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Dunkles Design verwenden'),
                value: settings.isDarkMode,
                onChanged: (v) => settings.setDarkMode(v),
                secondary: const Icon(Icons.dark_mode),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(Icons.access_time, color: colors.primary),
                title: const Text('24-Stunden-Format'),
                subtitle: const Text('Zeit als 24h oder 12h (AM/PM) anzeigen'),
                value: settings.use24hFormat,
                onChanged: (value) => settings.setUse24hFormat(value),
              ),
            ],
          ),
        ),

        // ── Benachrichtigungen (nicht im Web) ──
        if (!kIsWeb) ...[
          const SizedBox(height: 16),
          _SectionTitle('Benachrichtigungen'),
          if (!_loaded)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else ...[
            if (!_notifPermitted)
              Card(
                color: colors.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.notifications_off,
                      color: colors.onErrorContainer),
                  title: Text(
                    'Berechtigung fehlt',
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                  subtitle: Text(
                    'Du musst Benachrichtigungen erlauben, damit die App dich informieren kann.',
                    style: TextStyle(
                        color: colors.onErrorContainer.withValues(alpha: 0.8)),
                  ),
                  trailing: FilledButton(
                    onPressed: _requestPermissions,
                    child: const Text('Erlauben'),
                  ),
                ),
              ),
            if (!_notifPermitted) const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(Icons.notifications, color: colors.primary),
                    title: const Text('Benachrichtigungen aktivieren'),
                    subtitle: const Text('Hauptschalter für alle Notifications'),
                    value: _notifEnabled,
                    onChanged: _setMaster,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(Icons.chat_bubble_outline,
                        color: _notifEnabled
                            ? colors.primary
                            : colors.outlineVariant),
                    title: const Text('Chat-Nachrichten'),
                    subtitle: const Text('Bei neuen Nachrichten benachrichtigen'),
                    value: _notifChat,
                    onChanged: _notifEnabled
                        ? (v) =>
                            _setCategory(LocalNotificationManager.prefChat, v)
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(Icons.task_outlined,
                        color: _notifEnabled
                            ? colors.primary
                            : colors.outlineVariant),
                    title: const Text('Tasks fällig'),
                    subtitle: const Text(
                        'Erinnerungen am Fälligkeitstag und einen Tag vorher'),
                    value: _notifTasks,
                    onChanged: _notifEnabled
                        ? (v) =>
                            _setCategory(LocalNotificationManager.prefTasks, v)
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(Icons.kitchen_outlined,
                        color: _notifEnabled
                            ? colors.primary
                            : colors.outlineVariant),
                    title: const Text('Vorräte'),
                    subtitle:
                        const Text('Niedrige Bestände & ablaufende Vorräte'),
                    value: _notifPantry,
                    onChanged: _notifEnabled
                        ? (v) =>
                            _setCategory(LocalNotificationManager.prefPantry, v)
                        : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(Icons.event_outlined,
                        color: _notifEnabled
                            ? colors.primary
                            : colors.outlineVariant),
                    title: const Text('Termine'),
                    subtitle: const Text(
                        'Erinnerung vor Terminbeginn, auch bei geschlossener App'),
                    value: _notifPlanner,
                    onChanged: _notifEnabled
                        ? (v) => _setCategory(
                            LocalNotificationManager.prefPlanner, v)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Hinweis: Die App prüft alle ~6 Stunden im Hintergrund nach fälligen Tasks und ablaufenden Vorräten. Chat-Nachrichten kommen sofort, sobald eine Internetverbindung besteht.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.outline,
                    ),
              ),
            ),
          ],
        ],

        const SizedBox(height: 16),
        _SectionTitle('KI-Provider'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _providersLoading
                ? const SizedBox(
                    height: 40, child: Center(child: CircularProgressIndicator()))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_providers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Noch kein Anbieter. Füge einen hinzu und wähle ihn aus.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colors.outline),
                          ),
                        )
                      else
                        ..._providers.map((p) => Card(
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              color: p.isActive
                                  ? colors.primaryContainer.withValues(alpha: 0.35)
                                  : null,
                              child: ListTile(
                                leading: Icon(
                                  p.isActive
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: p.isActive ? colors.primary : null,
                                ),
                                title: Text(p.name),
                                subtitle: Text(_providerLabel(p.provider) +
                                    (p.model != null ? ' · ${p.model}' : '')),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'Bearbeiten',
                                      onPressed: () => _openProviderDialog(p),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Löschen',
                                      onPressed: () => _deleteProvider(p),
                                    ),
                                  ],
                                ),
                                onTap: () => _activate(p),
                              ),
                            )),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _openProviderDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Anbieter hinzufügen'),
                        ),
                      ),
                      if (_activeProvider != null) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Modell · ${_activeProvider!.name}',
                                  style: Theme.of(context).textTheme.labelMedium),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  _loadingActiveModels ? null : _loadActiveModels,
                              icon: _loadingActiveModels
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.download, size: 18),
                              label: const Text('Modelle'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_activeModels.isNotEmpty)
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue:
                                _activeModels.contains(_activeProvider!.model)
                                    ? _activeProvider!.model
                                    : null,
                            decoration: const InputDecoration(
                              labelText: 'Modell wählen',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _activeModels
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m,
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) _setActiveModel(v);
                            },
                          )
                        else
                          Text(
                            _activeProvider!.model != null
                                ? 'Aktuelles Modell: ${_activeProvider!.model}'
                                : 'Noch kein Modell gewählt – auf „Modelle" tippen.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.outline),
                          ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Hinweis: Bei Cloud-Anbietern werden Chat-Inhalte '
                        '(inkl. abgefragter Termine/Notizen/Journal) an den Anbieter '
                        'gesendet. Embeddings/RAG bleiben lokal.',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: colors.outline),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 16),
        _SectionTitle('KI-Assistent (Lokal)'),
        Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modell', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 8),
                    if (_aiModelsLoading)
                      const SizedBox(
                        height: 40,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_aiModels.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Keine Modelle verfügbar. Ollama API erreichbar?',
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      )
                    else
                      DropdownButton<String>(
                        isExpanded: true,
                        value: _aiModels.any((m) => m.name == settings.selectedAIModel)
                            ? settings.selectedAIModel
                            : _aiModels.first.name,
                        items: _aiModels
                            .map((model) => DropdownMenuItem(
                                  value: model.name,
                                  child: Text(model.name),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            settings.setSelectedAIModel(value);
                          }
                        },
                      ),
                    const SizedBox(height: 24),
                    Text('Temperatur: ${settings.aiTemperature.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.labelMedium),
                    Slider(
                      value: settings.aiTemperature,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: settings.aiTemperature.toStringAsFixed(2),
                      onChanged: (value) => settings.setAITemperature(value),
                    ),
                    const SizedBox(height: 12),
                    Text('Max Tokens: ${settings.aiMaxTokens}',
                        style: Theme.of(context).textTheme.labelMedium),
                    Slider(
                      value: settings.aiMaxTokens.toDouble(),
                      min: 100,
                      max: 4096,
                      divisions: 40,
                      label: settings.aiMaxTokens.toString(),
                      onChanged: (value) =>
                          settings.setAIMaxTokens(value.toInt()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _SectionTitle('Wetter'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _weatherCityCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) => settings.setWeatherCity(v),
                  decoration: InputDecoration(
                    labelText: 'Stadt',
                    hintText: 'z.B. Münster',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      tooltip: 'Speichern',
                      onPressed: () {
                        settings.setWeatherCity(_weatherCityCtrl.text);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Stadt gespeichert ✅')),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Wenn der Standortzugriff erlaubt ist, wird der aktuelle Standort '
                  'verwendet – sonst diese Stadt. Immer °C (metrisch).',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: colors.outline),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        _SectionTitle('Sonstiges'),
        SettingsTile(
          icon: Icons.info_outline,
          label: 'Über',
          subtitle: 'Version 1.0.0',
          iconColor: colors.secondary,
          onTap: () {},
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

/// Passwort abfragen, um es fuer die biometrische Anmeldung zu hinterlegen.
///
/// Es steht nirgends im Klartext herum, wo die App es sonst herbekommen
/// koennte – deshalb muss es hier einmal eingegeben werden.
class _PasswortAbfrage extends StatefulWidget {
  final String name;

  const _PasswortAbfrage({required this.name});

  @override
  State<_PasswortAbfrage> createState() => _PasswortAbfrageState();
}

class _PasswortAbfrageState extends State<_PasswortAbfrage> {
  final _feld = TextEditingController();
  bool _sichtbar = false;

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.name} einrichten'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gib dein Passwort noch einmal ein. Es wird verschlüsselt auf '
            'diesem Gerät hinterlegt und nur nach erfolgreicher '
            '${widget.name}-Prüfung verwendet.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _feld,
            autofocus: true,
            obscureText: !_sichtbar,
            decoration: InputDecoration(
              labelText: 'Passwort',
              suffixIcon: IconButton(
                icon: Icon(_sichtbar ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _sichtbar = !_sichtbar),
              ),
            ),
            onSubmitted: (wert) => Navigator.pop(context, wert),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _feld.text),
          child: const Text('Einrichten'),
        ),
      ],
    );
  }
}
