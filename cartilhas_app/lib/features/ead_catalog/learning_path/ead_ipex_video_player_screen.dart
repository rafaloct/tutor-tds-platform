import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Restrict public MP4/VTT video to the published IPEX uploads directory.
class EadIpexVideoPolicy {
  static const host = 'ead.ipexdesenvolvimento.cloud';

  static bool allows(Uri? uri, String extension) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.host == host &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.path.startsWith('/wp-content/uploads/tutor-tds/') &&
      uri.path.toLowerCase().endsWith(extension) &&
      !uri.path.contains('..') &&
      !uri.toString().contains(RegExp(r'%(2e|2f|5c)', caseSensitive: false));

  static String document(Uri video, Uri? captions) {
    if (!allows(video, '.mp4') ||
        (captions != null && !allows(captions, '.vtt'))) {
      throw const FormatException('Endereço de vídeo não autorizado.');
    }
    final source = const HtmlEscape(
      HtmlEscapeMode.attribute,
    ).convert(video.toString());
    final vtt = captions == null
        ? ''
        : '<track kind="captions" src="${const HtmlEscape(HtmlEscapeMode.attribute).convert(captions.toString())}" srclang="pt-BR" label="Português" default>';
    return '<!doctype html><html lang="pt-BR"><head>'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<style>html,body{margin:0;background:#111;color:white}'
        'video{display:block;width:100%;height:auto;max-height:100vh}</style>'
        '</head><body><video controls playsinline preload="metadata">'
        '<source src="$source" type="video/mp4">$vtt'
        'Seu navegador não consegue reproduzir esta videoaula.'
        '</video></body></html>';
  }
}

/// No MediaItem, video analytics, progress, grades, attendance or completion.
class EadIpexVideoPlayerScreen extends StatefulWidget {
  const EadIpexVideoPlayerScreen({
    super.key,
    required this.video,
    this.captions,
    required this.lessonTitle,
    this.openExternal,
    this.playerFactory,
  });

  final Uri video;
  final Uri? captions;
  final String lessonTitle;
  final Future<bool> Function(Uri)? openExternal;
  final Widget Function(Uri, Uri?, VoidCallback, VoidCallback)? playerFactory;

  @override
  State<EadIpexVideoPlayerScreen> createState() =>
      _EadIpexVideoPlayerScreenState();
}

class _EadIpexVideoPlayerScreenState extends State<EadIpexVideoPlayerScreen> {
  bool _ready = false;
  bool _failed = false;

  Future<void> _external() async {
    try {
      final opened =
          await (widget.openExternal?.call(widget.video) ??
              launchUrl(widget.video, mode: LaunchMode.externalApplication));
      if (opened || !mounted) return;
    } on Object {
      // Show a generic error, never a remote URL, token or HTML.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o vídeo no navegador.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid =
        EadIpexVideoPolicy.allows(widget.video, '.mp4') &&
        (widget.captions == null ||
            EadIpexVideoPolicy.allows(widget.captions, '.vtt'));
    return Scaffold(
      appBar: AppBar(title: const Text('Videoaula do IPEX')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.lessonTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (valid && !_failed)
            AspectRatio(
              aspectRatio: 16 / 9,
              child:
                  widget.playerFactory?.call(
                    widget.video,
                    widget.captions,
                    () => setState(() => _ready = true),
                    () => setState(() => _failed = true),
                  ) ??
                  _IpexWebView(
                    video: widget.video,
                    captions: widget.captions,
                    onReady: () => setState(() => _ready = true),
                    onError: () => setState(() => _failed = true),
                  ),
            ),
          if (valid && !_failed && !_ready)
            const LinearProgressIndicator(
              semanticsLabel: 'Carregando videoaula do IPEX',
            ),
          if (!valid || _failed)
            const Text('Vídeo indisponível. Você pode tentar pelo site EAD.'),
          const SizedBox(height: 12),
          const Text(
            'Reprodução online. As legendas em português estão disponíveis '
            'quando fornecidas pelo IPEX. Assistir não registra '
            'conclusão, nota, presença ou certificado.',
          ),
          const SizedBox(height: 12),
          if (valid)
            OutlinedButton.icon(
              onPressed: _external,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir vídeo no navegador'),
            ),
        ],
      ),
    );
  }
}

class _IpexWebView extends StatefulWidget {
  const _IpexWebView({
    required this.video,
    this.captions,
    required this.onReady,
    required this.onError,
  });
  final Uri video;
  final Uri? captions;
  final VoidCallback onReady;
  final VoidCallback onError;

  @override
  State<_IpexWebView> createState() => _IpexWebViewState();
}

class _IpexWebViewState extends State<_IpexWebView> {
  WebViewController? _controller;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 20), widget.onError);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.disabled);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // Video resources are subrequests; never permit arbitrary page navigation.
            return request.url == 'about:blank' ||
                    request.url == 'https://ead.ipexdesenvolvimento.cloud/'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            _timeout?.cancel();
            widget.onReady(); // HTML loaded, NOT proof of playback.
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            _timeout?.cancel();
            widget.onError();
          },
        ),
      );
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadHtmlString(
        EadIpexVideoPolicy.document(widget.video, widget.captions),
        baseUrl: 'https://ead.ipexdesenvolvimento.cloud/',
      );
    } on Object {
      if (mounted) widget.onError();
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _controller == null
      ? const SizedBox.shrink()
      : WebViewWidget(controller: _controller!);
}
