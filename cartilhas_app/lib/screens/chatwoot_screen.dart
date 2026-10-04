import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../features/auth/data/auth_repository.dart';
import '../services/privacy_preferences.dart';
import '../services/chatwoot_script_value.dart';

// Import condicional: usa JS no web, stub no mobile
import '../services/chatwoot_web_impl.dart'
    if (dart.library.io) '../services/chatwoot_web_stub.dart';

// webview_flutter compila em todas as plataformas (no-op no web)
import 'package:webview_flutter/webview_flutter.dart';

String get _chatwootBase => AppConfig.chatwootBaseUrl;
String get _websiteToken => AppConfig.chatwootWebsiteToken;
const _whatsappSuporte = '5563993010823';

class ChatwootScreen extends StatefulWidget {
  const ChatwootScreen({super.key});

  @override
  State<ChatwootScreen> createState() => _ChatwootScreenState();
}

class _ChatwootScreenState extends State<ChatwootScreen> {
  // Campos usados apenas no mobile (WebView)
  WebViewController? _controller;
  bool _loading = true;
  bool _error = false;

  // Campos usados no web
  bool _webOpened = false;
  String _userName = '';
  String _supportContactId = '';
  String? _identifierHash;

  Future<String?> _resolveSupportId(SharedPreferences preferences) async {
    if (!AppConfig.signedSupportIdentity) {
      return _getSupportContactId(preferences);
    }
    try {
      if (!mounted) return null;
      final identity = await context.read<AuthRepository>().supportIdentity();
      if (!mounted) return null;
      _identifierHash = identity['identifier_hash'];
      return identity['identifier'];
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
      return null;
    }
  }

  Future<String> _getSupportContactId(SharedPreferences preferences) async {
    const key = 'support_contact_id_v1';
    final existing = preferences.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final bytes = List<int>.generate(18, (_) => Random.secure().nextInt(256));
    final generated = base64UrlEncode(bytes).replaceAll('=', '');
    await preferences.setString(key, generated);
    return generated;
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWeb();
    } else {
      _initWebView();
    }
  }

  @override
  void dispose() {
    if (kIsWeb && _webOpened) chatwootClose();
    super.dispose();
  }

  // ── WEB ────────────────────────────────────────────────────────────
  Future<void> _initWeb() async {
    final prefs = await SharedPreferences.getInstance();
    final canIdentifyUser = await PrivacyPreferences.hasConsent();
    final name = canIdentifyUser ? prefs.getString('user_name') ?? '' : '';
    final phone = canIdentifyUser ? prefs.getString('user_phone') ?? '' : '';
    final supportContactId = await _resolveSupportId(prefs);
    if (!mounted || supportContactId == null) return;

    setState(() {
      _userName = name;
      _supportContactId = supportContactId;
      _loading = false;
    });

    chatwootOpen(
      _chatwootBase,
      _websiteToken,
      supportContactId,
      name,
      phone,
      identifierHash: _identifierHash,
    );
    setState(() => _webOpened = true);
  }

  // ── MOBILE (WebView) ───────────────────────────────────────────────
  Future<void> _initWebView() async {
    final prefs = await SharedPreferences.getInstance();
    final canIdentifyUser = await PrivacyPreferences.hasConsent();
    final name = canIdentifyUser
        ? prefs.getString('user_name') ?? 'Aluno TDS'
        : 'Aluno TDS';
    final phone = canIdentifyUser ? prefs.getString('user_phone') ?? '' : '';
    final supportContactId = await _resolveSupportId(prefs);
    if (!mounted || supportContactId == null) return;
    final signedField = _identifierHash == null
        ? ''
        : 'identifier_hash: ${chatwootScriptValue(_identifierHash!)},';
    final encodedSupportId = chatwootScriptValue(supportContactId);
    final encodedName = chatwootScriptValue(name);
    final encodedPhone = chatwootScriptValue(phone);

    final html =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { height: 100%; width: 100%; overflow: hidden; background: #f5f5f5; }
    #loading {
      display: flex; flex-direction: column; align-items: center;
      justify-content: center; height: 100vh;
      font-family: Arial, sans-serif; color: #666; gap: 12px;
    }
    .dot { width: 10px; height: 10px; border-radius: 50%;
           background: #093AF4; animation: pulse 1s infinite alternate; }
    .dot:nth-child(2) { animation-delay: .3s; }
    .dot:nth-child(3) { animation-delay: .6s; }
    .dots { display: flex; gap: 8px; }
    @keyframes pulse { to { opacity: .2; transform: scale(.8); } }
  </style>
</head>
<body>
  <div id="loading">
    <div class="dots">
      <div class="dot"></div><div class="dot"></div><div class="dot"></div>
    </div>
    <p>Conectando ao suporte TDS...</p>
  </div>
  <script>
    window.chatwootSettings = {
      hideMessageBubble: false,
      position: "right",
      locale: "pt_BR",
      type: "standard",
      darkMode: "auto",
    };
    (function(d,t){
      var BASE_URL = "$_chatwootBase";
      var g = d.createElement(t), s = d.getElementsByTagName(t)[0];
      g.src = BASE_URL + "/packs/js/sdk.js";
      g.defer = true; g.async = true;
      s.parentNode.insertBefore(g,s);
      g.onload = function() {
        window.chatwootSDK.run({ websiteToken: "$_websiteToken", baseUrl: BASE_URL });
        window.addEventListener("chatwoot:ready", function() {
          document.getElementById("loading").style.display = "none";
          window.\$chatwoot.toggle("open");
          window.\$chatwoot.setUser($encodedSupportId, {
            name: $encodedName,
            phone_number: $encodedPhone,
            $signedField
          });
          window.\$chatwoot.setCustomAttributes({ origem: "App Cartilhas TDS" });
        });
      };
    })(document,"script");
  </script>
</body>
</html>
''';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = true;
              });
            }
          },
        ),
      )
      ..loadHtmlString(html, baseUrl: _chatwootBase);

    if (mounted) setState(() => _controller = controller);
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
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recarregar',
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = false;
                });
                _controller?.reload();
              },
            ),
        ],
      ),
      body: kIsWeb ? _buildWebBody() : _buildMobileBody(),
    );
  }

  // ── CORPO WEB ──────────────────────────────────────────────────────
  Widget _buildWebBody() {
    if (_error) {
      return _ErrorView(
        onRetry: () {
          setState(() {
            _error = false;
            _loading = true;
          });
          _initWeb();
        },
      );
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
              if (_webOpened)
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
                  onPressed: () => chatwootOpen(
                    _chatwootBase,
                    _websiteToken,
                    _supportContactId,
                    _userName,
                    '',
                    identifierHash: _identifierHash,
                  ),
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
      return _ErrorView(
        onRetry: () {
          setState(() {
            _loading = true;
            _error = false;
          });
          _initWebView();
        },
      );
    }

    return Stack(
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
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
          ],
        ),
      ),
    );
  }
}
