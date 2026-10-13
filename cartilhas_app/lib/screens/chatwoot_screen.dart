import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/support/chatwoot_config_repository.dart';
import '../features/support/chatwoot_mobile_host.dart';
import '../services/privacy_preferences.dart';
import '../services/chatwoot_web_impl.dart'
    if (dart.library.io) '../services/chatwoot_web_stub.dart';

const _whatsappSuporte = '5563993010823';

class ChatwootScreen extends StatefulWidget {
  const ChatwootScreen({
    super.key,
    this.configurationRepository,
    this.mobileHostFactory,
    this.widgetReadyTimeout = const Duration(seconds: 20),
  });

  final ChatwootConfigRepository? configurationRepository;
  final ChatwootMobileHost Function()? mobileHostFactory;
  final Duration widgetReadyTimeout;

  @override
  State<ChatwootScreen> createState() => _ChatwootScreenState();
}

class _ChatwootScreenState extends State<ChatwootScreen> {
  late final ChatwootConfigRepository _repository;
  ChatwootMobileHost? _mobileHost;
  Timer? _readyTimer;
  Timer? _authGuardTimer;
  int _generation = 0;
  int? _webLease;
  Future<void> _closing = Future<void>.value();
  bool _loading = true;
  bool _error = false;
  bool _webOpened = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.configurationRepository ?? HttpChatwootConfigRepository();
    _loadSupport();
  }

  Future<void> _closeHost() {
    _readyTimer?.cancel();
    _readyTimer = null;
    _authGuardTimer?.cancel();
    _authGuardTimer = null;
    final host = _mobileHost;
    _mobileHost = null;
    if (host != null) {
      _closing = _closing.then((_) => host.close());
    }
    if (_webLease != null) chatwootClose(_webLease);
    _webLease = null;
    _webOpened = false;
    return _closing;
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_closeHost());
    if (widget.configurationRepository == null) {
      (_repository as HttpChatwootConfigRepository).dispose();
    }
    super.dispose();
  }

  bool _current(int generation, AuthRepository? auth, int? authGeneration) =>
      mounted &&
      generation == _generation &&
      auth?.sessionGeneration == authGeneration;

  void _fail(int generation) {
    if (!mounted || generation != _generation) return;
    _generation++;
    unawaited(_closeHost());
    setState(() {
      _loading = false;
      _error = true;
    });
  }

  Future<_SupportIdentity> _resolveSupportId(
    SharedPreferences preferences,
    AuthRepository? auth,
  ) async {
    if (AppConfig.signedSupportIdentity) {
      if (auth == null) throw const ChatwootConfigUnavailable();
      final identity = await auth.supportIdentity();
      return _SupportIdentity(
        identity['identifier']!,
        identity['identifier_hash'],
      );
    }
    const key = 'support_contact_id_v1';
    final existing = preferences.getString(key);
    if (existing != null && existing.isNotEmpty) {
      return _SupportIdentity(existing, null);
    }
    final bytes = List<int>.generate(18, (_) => Random.secure().nextInt(256));
    final generated = base64UrlEncode(bytes).replaceAll('=', '');
    await preferences.setString(key, generated);
    return _SupportIdentity(generated, null);
  }

  Future<void> _loadSupport() async {
    final generation = ++_generation;
    final closing = _closeHost();
    if (kIsWeb) _webLease = chatwootReserve();
    setState(() {
      _loading = true;
      _error = false;
    });
    final auth = context.read<AuthRepository?>();
    final authGeneration = auth?.sessionGeneration;
    // AuthRepository exposes a generation rather than a notification stream.
    // Keep an open SDK context from surviving an account change in silence.
    if (auth != null) {
      _authGuardTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!_current(generation, auth, authGeneration)) _fail(generation);
      });
    }
    try {
      await closing;
      if (!_current(generation, auth, authGeneration)) {
        _fail(generation);
        return;
      }
      final config = await _repository.fetch();
      if (!_current(generation, auth, authGeneration)) {
        _fail(generation);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!_current(generation, auth, authGeneration)) {
        _fail(generation);
        return;
      }
      final consent = await PrivacyPreferences.hasConsent();
      if (!_current(generation, auth, authGeneration)) {
        _fail(generation);
        return;
      }
      final identity = await _resolveSupportId(prefs, auth);
      if (!_current(generation, auth, authGeneration)) {
        _fail(generation);
        return;
      }
      final name = consent
          ? prefs.getString('user_name') ?? 'Aluno TDS'
          : 'Aluno TDS';
      final phone = consent ? prefs.getString('user_phone') ?? '' : '';
      _readyTimer = Timer(widget.widgetReadyTimeout, () => _fail(generation));
      void opened() {
        if (!_current(generation, auth, authGeneration)) {
          _fail(generation);
          return;
        }
        _readyTimer?.cancel();
        setState(() {
          _loading = false;
          _webOpened = kIsWeb;
        });
      }

      if (kIsWeb) {
        final lease = _webLease!;
        if (!chatwootSessionCurrent(lease)) {
          _fail(generation);
          return;
        }
        chatwootOpen(
          config.baseUrl,
          config.websiteToken,
          identity.id,
          name,
          phone,
          identifierHash: identity.hash,
          lease: lease,
          canIdentify: () => _current(generation, auth, authGeneration),
          onOpened: opened,
          onError: () => _fail(generation),
          onClosed: () {
            if (_current(generation, auth, authGeneration)) {
              setState(() => _webOpened = false);
            }
          },
          loadTimeout: widget.widgetReadyTimeout,
        );
      } else {
        final host = widget.mobileHostFactory?.call() ?? WebViewChatwootHost();
        setState(() => _mobileHost = host);
        await host.load(
          config,
          onReady: () {
            if (!_current(generation, auth, authGeneration)) {
              _fail(generation);
              return;
            }
            unawaited(
              host
                  .identify(
                    id: identity.id,
                    name: name,
                    phone: phone,
                    identifierHash: identity.hash,
                  )
                  .catchError((Object _) => _fail(generation)),
            );
          },
          onOpened: opened,
          onError: () => _fail(generation),
        );
      }
    } on Object {
      _fail(generation);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.support_agent, size: 20),
            SizedBox(width: 8),
            Text('Suporte TDS'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _loadSupport,
          ),
        ],
      ),
      body: kIsWeb ? _buildWebBody() : _buildMobileBody(),
    );
  }

  // ── CORPO WEB ──────────────────────────────────────────────────────
  Widget _buildWebBody() {
    if (_error) {
      return _ErrorView(onRetry: _loadSupport);
    }
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF093AF4)),
            SizedBox(height: 14),
            Text(
              'Abrindo suporte...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 52,
                  color: Color(0xFF093AF4),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _webOpened ? 'Chat de suporte aberto!' : 'Suporte TDS',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _webOpened
                    ? 'O chat do suporte TDS foi aberto no canto inferior direito da tela. '
                          'Procure o ícone de balão de conversa.'
                    : 'Escolha como prefere falar com a equipe TDS.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Reabrir chat
              FilledButton.icon(
                icon: const Icon(Icons.chat_bubble),
                label: const Text('Reabrir chat'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF093AF4),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _loadSupport,
              ),

              const SizedBox(height: 12),

              // WhatsApp fallback
              OutlinedButton.icon(
                icon: const Icon(Icons.phone_in_talk, color: Color(0xFF25D366)),
                label: const Text(
                  'WhatsApp +55 63 9301-0823',
                  style: TextStyle(color: Color(0xFF25D366)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF25D366)),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://wa.me/$_whatsappSuporte?text=${Uri.encodeComponent("Olá! Preciso de ajuda com o App Cartilhas TDS.")}',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CORPO MOBILE (WebView) ─────────────────────────────────────────
  Widget _buildMobileBody() {
    if (_error) {
      return _ErrorView(onRetry: _loadSupport);
    }

    return Stack(
      children: [
        if (_mobileHost != null) _mobileHost!.build(),
        if (_loading)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF093AF4)),
                SizedBox(height: 14),
                Text(
                  'Abrindo suporte...',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Não foi possível conectar ao suporte.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verifique sua conexão e tente novamente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              onPressed: onRetry,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.phone_in_talk),
              label: const Text('WhatsApp +55 63 9301-0823'),
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://wa.me/$_whatsappSuporte?text=${Uri.encodeComponent("Olá! Preciso de ajuda com o App Cartilhas TDS.")}',
                ),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportIdentity {
  const _SupportIdentity(this.id, this.hash);
  final String id;
  final String? hash;
}
