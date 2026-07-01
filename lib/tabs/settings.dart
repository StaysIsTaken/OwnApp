import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  bool _notifEnabled = true;
  bool _notifChat = true;
  bool _notifTasks = true;
  bool _notifPantry = true;
  bool _notifPermitted = true;
  bool _loaded = false;
  List<AIModel> _aiModels = [];
  bool _aiModelsLoading = true;

  // KI-Provider (serverseitig, pro User)
  String _provider = 'ollama';
  bool _hasKey = false;
  bool _aiSettingsLoading = true;
  bool _savingAiSettings = false;
  final TextEditingController _apiKeyCtrl = TextEditingController();
  final TextEditingController _cloudModelCtrl = TextEditingController();
  final TextEditingController _baseUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotifSettings();
    _loadAIModels();
    _loadAiProviderSettings();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _cloudModelCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAiProviderSettings() async {
    try {
      final s = await AiSettingsService.get();
      if (!mounted) return;
      setState(() {
        _provider = s.provider;
        _hasKey = s.hasKey;
        _cloudModelCtrl.text = s.model ?? '';
        _baseUrlCtrl.text = s.baseUrl ?? '';
        _aiSettingsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _aiSettingsLoading = false);
    }
  }

  Future<void> _saveAiProviderSettings() async {
    setState(() => _savingAiSettings = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final s = await AiSettingsService.save(
        provider: _provider,
        // Key nur senden, wenn etwas eingegeben wurde (sonst unverändert lassen)
        apiKey: _apiKeyCtrl.text.isNotEmpty ? _apiKeyCtrl.text : null,
        baseUrl: _baseUrlCtrl.text.trim(),
        model: _cloudModelCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _hasKey = s.hasKey;
        _apiKeyCtrl.clear();
        _savingAiSettings = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('KI-Einstellungen gespeichert ✅')),
      );
    } catch (e) {
      if (mounted) setState(() => _savingAiSettings = false);
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
    final permitted = await mgr.areNotificationsEnabled();

    if (!mounted) return;
    setState(() {
      _notifEnabled = enabled;
      _notifChat = chat;
      _notifTasks = tasks;
      _notifPantry = pantry;
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
            child: _aiSettingsLoading
                ? const SizedBox(
                    height: 40, child: Center(child: CircularProgressIndicator()))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Anbieter',
                          style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: _provider,
                        items: const [
                          DropdownMenuItem(
                              value: 'ollama', child: Text('Lokal (Ollama)')),
                          DropdownMenuItem(
                              value: 'openrouter', child: Text('OpenRouter')),
                          DropdownMenuItem(
                              value: 'gemini', child: Text('Google Gemini')),
                        ],
                        onChanged: (v) =>
                            setState(() => _provider = v ?? 'ollama'),
                      ),
                      if (_provider != 'ollama') ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _apiKeyCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'API-Key',
                            hintText: _hasKey
                                ? '•••••••• (gespeichert – zum Ändern neu eingeben)'
                                : 'API-Key einfügen',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _cloudModelCtrl,
                          decoration: InputDecoration(
                            labelText: 'Modell',
                            hintText: _provider == 'gemini'
                                ? 'z.B. gemini-2.5-flash'
                                : 'z.B. google/gemini-2.0-flash-exp:free',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _baseUrlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Base-URL (optional)',
                            hintText: 'leer = Standard des Anbieters',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hinweis: Bei einem Cloud-Anbieter werden Chat-Inhalte '
                          '(inkl. abgefragter Termine/Notizen/Journal) an diesen '
                          'gesendet. Embeddings/RAG bleiben lokal.',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.outline,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed:
                              _savingAiSettings ? null : _saveAiProviderSettings,
                          icon: _savingAiSettings
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save),
                          label: const Text('Speichern'),
                        ),
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
