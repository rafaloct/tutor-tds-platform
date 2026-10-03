import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/external_identity_service.dart';
import '../features/auth/models/auth_session.dart';
import '../features/auth/models/external_auth_result.dart';
import '../features/auth/presentation/account_login_dialog.dart';
import '../features/auth/presentation/external_profile_completion_screen.dart';
import '../features/profile/data/profile_data_store.dart';
import '../widgets/responsive_body.dart';
import '../widgets/tds_brand_stripe.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    this.profileDataStore,
    this.skipExistingUserRedirect = false,
  });

  final ProfileDataStore? profileDataStore;
  final bool skipExistingUserRedirect;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  StreamSubscription<void>? _externalSubscription;
  bool _externalListenerReady = false;
  bool _externalBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_externalListenerReady) return;
    _externalListenerReady = true;
    final external = context.read<ExternalIdentityService>();
    if (!external.isConfigured) return;
    _externalSubscription = external.sessionChanges.listen((_) {
      _exchangeExternalSession();
    });
    scheduleMicrotask(_exchangeExternalSession);
  }

  @override
  void dispose() {
    _externalSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkExistingUser() async {
    if (widget.skipExistingUserRedirect) return;
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    if (name.isNotEmpty && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _finishSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', session.user.name);
    if (!mounted) return;
    if (widget.skipExistingUserRedirect && Navigator.canPop(context)) {
      Navigator.of(context).pop(session);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _explore() async {
    if (widget.skipExistingUserRedirect && Navigator.canPop(context)) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _exchangeExternalSession() async {
    if (_externalBusy || !mounted) return;
    final external = context.read<ExternalIdentityService>();
    if (!external.isConfigured) return;
    setState(() {
      _externalBusy = true;
      _error = null;
    });
    try {
      final result = await external.exchangeCurrentSession();
      if (!mounted || result == null) return;
      if (result.isAuthenticated) {
        await _finishSession(result.session!);
        return;
      }
      if (result.status ==
          ExternalAuthStatus.profileCompletionRequired) {
        final session = await Navigator.of(context).push<AuthSession>(
          MaterialPageRoute<AuthSession>(
            builder: (_) => ExternalProfileCompletionScreen(
              onboardingToken: result.onboardingToken!,
              verifiedEmail: result.verifiedEmail,
              profileDataStore: widget.profileDataStore,
            ),
          ),
        );
        if (session != null && mounted) {
          await _finishSession(session);
        }
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _externalBusy = false);
    }
  }

  Future<void> _google() async {
    setState(() => _error = null);
    try {
      final opened =
          await context.read<ExternalIdentityService>().signInWithGoogle();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Google cancelado.')),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _magicLink() async {
    var email = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Receber link por e-mail'),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'E-mail'),
            onChanged: (value) => email = value,
            validator: (value) {
              final normalized = (value ?? '').trim();
              return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(normalized)
                  ? null
                  : 'Informe um e-mail válido';
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Enviar link'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _error = null);
    try {
      await context
          .read<ExternalIdentityService>()
          .requestMagicLink(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Link solicitado. Abra o e-mail neste aparelho para continuar.',
            ),
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _cpfLogin() async {
    final session = await showAccountLoginDialog(context);
    if (session != null && mounted) await _finishSession(session);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final externalConfigured =
        context.read<ExternalIdentityService>().isConfigured;
    return Scaffold(
      backgroundColor: colors.primary,
      body: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Center(
          child: ResponsiveBody(
            maxWidth: 520,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Material(
                color: colors.surface,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ColoredBox(
                        color: colors.primary,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            24,
                            28,
                            24,
                            30,
                          ),
                          child: Column(
                            children: [
                              Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 300),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Image.asset(
                                  'assets/branding/logo_tds_fundo_branco.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Tutor TDS',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Explore cursos públicos. Entre somente '
                                'quando precisar de recursos da sua conta.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const TdsBrandStripe(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                              key: const ValueKey('explore-courses'),
                              onPressed: _externalBusy ? null : _explore,
                              icon: const Icon(Icons.explore_outlined),
                              label: const Text('Explorar cursos'),
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              key: const ValueKey('google-login'),
                              onPressed: externalConfigured && !_externalBusy
                                  ? _google
                                  : null,
                              icon: const Icon(Icons.account_circle_outlined),
                              label: const Text('Continuar com Google'),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              key: const ValueKey('magic-link'),
                              onPressed: externalConfigured && !_externalBusy
                                  ? _magicLink
                                  : null,
                              icon: const Icon(Icons.mail_outline),
                              label: const Text('Receber link por e-mail'),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Já possui cadastro?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('cpf-login'),
                              onPressed: _externalBusy ? null : _cpfLogin,
                              child: const Text('Entrar com CPF'),
                            ),
                            if (!externalConfigured) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Google e link por e-mail serão habilitados '
                                'quando o provedor de identidade deste '
                                'ambiente estiver configurado.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            ],
                            if (_externalBusy) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(),
                            ],
                          ],
                        ),
                      ),
                    ],
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
