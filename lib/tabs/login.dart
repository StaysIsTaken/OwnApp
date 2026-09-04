import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:provider/provider.dart';
import '../dataservice/login_service.dart';
import 'package:productivity/dataservice/api_client.dart';
import 'package:productivity/dataservice/biometric_service.dart';
import 'package:productivity/utils/snack.dart';
import 'package:productivity/widgets/server_dialog.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  /// Gemerkte Zugangsdaten, wenn es welche gibt und sie zu diesem Server
  /// gehoeren. Sonst null – dann bleibt es beim Passwort.
  GemerkterZugang? _gemerkt;
  String _biometrieName = 'Face ID';

  /// Nur der Rechnername – die volle Adresse wäre hier zu viel und steht
  /// im Dialog.
  String get _serverName {
    final uri = Uri.tryParse(ApiClient.baseUrl);
    return uri?.host.isNotEmpty == true ? uri!.host : ApiClient.baseUrl;
  }

  Future<void> _serverAendern() async {
    final geaendert = await showDialog<bool>(
      context: context,
      builder: (_) => const ServerDialog(),
    );
    if (geaendert == true && mounted) {
      setState(() {});
      showSnack('Server geändert auf $_serverName');
    }
  }

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animController.forward();
    });
    _biometrieVorbereiten();
  }

  Future<void> _biometrieVorbereiten() async {
    if (!await BiometricService.verfuegbar()) return;
    final gemerkt = await BiometricService.gemerkt();
    if (!mounted) return;
    if (!BiometricService.anbieten(
        gemerkt: gemerkt, aktuellerServer: ApiClient.baseUrl)) {
      return;
    }
    final name = await BiometricService.bezeichnung();
    if (!mounted) return;
    setState(() {
      _gemerkt = gemerkt;
      _biometrieName = name;
    });
  }

  /// Anmelden mit dem, was in der Keychain liegt.
  ///
  /// Der Sensor entscheidet nur, ob die Zugangsdaten herausgegeben werden –
  /// angemeldet wird danach ganz normal ueber `/auth/login`.
  Future<void> _mitBiometrie() async {
    final zugang = _gemerkt;
    if (zugang == null) return;

    final ok = await BiometricService.pruefen(
        'Anmelden als ${zugang.benutzername}');
    if (!ok || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await LoginService.login(
          username: zugang.benutzername, password: zugang.passwort);
      final user = await LoginService.currentUser;
      if (!mounted) return;
      context.read<UserProvider>().login(user);
      Navigator.pushReplacementNamed(context, '/home');
    } on DioException catch (e) {
      // Passwort geaendert oder Konto deaktiviert: die gemerkten Daten sind
      // wertlos geworden. Wegwerfen, sonst scheitert es bei jedem Start
      // erneut und niemand versteht, warum.
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await BiometricService.vergessen();
        if (mounted) setState(() => _gemerkt = null);
      }
      showErrorSnack(e.response?.data is Map
          ? (e.response!.data['detail'] ?? 'Anmeldung fehlgeschlagen')
          : 'Anmeldung fehlgeschlagen');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Nach erfolgreicher Anmeldung einmal fragen – nicht ungefragt speichern.
  Future<void> _merkenAnbieten(String benutzername, String passwort) async {
    if (!await BiometricService.verfuegbar()) return;
    if (await BiometricService.gemerkt() != null) return;
    if (!mounted) return;

    final name = await BiometricService.bezeichnung();
    if (!mounted) return;
    final ja = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Künftig mit $name anmelden?'),
        content: Text(
          'Dein Passwort wird dafür verschlüsselt auf diesem Gerät '
          'hinterlegt und nur nach erfolgreicher $name-Prüfung verwendet. '
          'Du kannst das in den Einstellungen jederzeit wieder abschalten.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nein danke')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Einrichten')),
        ],
      ),
    );
    if (ja == true) {
      await BiometricService.merken(
          benutzername: benutzername, passwort: passwort);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await LoginService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      final user = await LoginService.currentUser;
      await _merkenAnbieten(
          _usernameController.text.trim(), _passwordController.text);
      // Guard erst NACH dem letzten await – sonst kann die Seite waehrend
      // `currentUser` verschwinden und der Zugriff auf context wirft.
      if (!mounted) return;
      context.read<UserProvider>().login(user);
      Navigator.pushReplacementNamed(context, '/home');
    } on DioException catch (e) {
      final message = e.response?.data['detail'] ?? 'Falsche Zugangsdaten';
      showErrorSnack(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Icon ────────────────────────────────
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.construction_rounded,
                              size: 36,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Headline ─────────────────────────────
                        Text(
                          'Willkommen\nzurück 👋',
                          style: theme.textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Melde dich an um fortzufahren.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // ── Benutzername ─────────────────────────
                        _FieldLabel(label: 'Benutzername'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'dein_name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Bitte Benutzernamen eingeben';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // ── Passwort ─────────────────────────────
                        _FieldLabel(label: 'Passwort'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Bitte Passwort eingeben';
                            }
                            if (v.length < 6) return 'Mindestens 6 Zeichen';
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // ── Anmelden Button ──────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Anmelden',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                        // ── Mit Face ID anmelden ─────────────────
                        // Nur wenn wirklich etwas hinterlegt ist und es zu
                        // diesem Server gehoert – sonst waere der Knopf ein
                        // Versprechen, das er nicht halten kann.
                        if (_gemerkt != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _mitBiometrie,
                              icon: const Icon(Icons.fingerprint, size: 22),
                              label: Text(
                                'Mit $_biometrieName anmelden',
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // ── Registrieren Button ──────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/register'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Registrieren',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Server ───────────────────────────────
                        // Hier und nicht nur in den Einstellungen: vor der
                        // Anmeldung kommt man dort nicht hin, und wer sich
                        // nicht anmelden kann, hat oft genau hier das
                        // Problem.
                        Center(
                          child: TextButton.icon(
                            onPressed: _serverAendern,
                            icon: const Icon(Icons.dns_outlined, size: 16),
                            label: Text(
                              _serverName,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),

                        // ── Footer ───────────────────────────────
                        Center(
                          child: Text(
                            'Nur für private Nutzung.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
