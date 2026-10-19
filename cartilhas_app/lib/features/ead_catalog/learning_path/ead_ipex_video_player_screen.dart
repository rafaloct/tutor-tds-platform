import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Restrict public MP4/VTT video to the published IPEX uploads directory.
class EadIpexVideoPolicy {
  static const host = 'ead.ipexdesenvolvimento.cloud';

  // Only this local script runs in the WebView. VTT cues are written as text,
  // never inserted as HTML or evaluated as JavaScript.
  static const _captionScript = r'''
(() => {
  const video = document.getElementById('lesson-video');
  const trackElement = document.getElementById('portuguese-track');
  const button = document.getElementById('caption-toggle');
  const output = document.getElementById('caption-text');
  const track = video.textTracks[0];
  let enabled = true;

  function render() {
    // Hidden loads active cues but keeps WebView's native overlay off the image.
    for (const item of video.textTracks) item.mode = 'hidden';
    const cues = enabled && track ? track.activeCues : null;
    output.textContent = cues
      ? Array.from(cues, cue => cue.getCueAsHTML
          ? cue.getCueAsHTML().textContent : cue.text).join('\n')
      : '';
  }

  button.addEventListener('click', () => {
    enabled = !enabled;
    button.setAttribute('aria-pressed', String(enabled));
    button.textContent = enabled ? 'Ocultar legendas' : 'Mostrar legendas';
    render();
  });
  trackElement.addEventListener('load', render);
  video.addEventListener('loadedmetadata', render);
  if (track) track.addEventListener('cuechange', render);
  video.textTracks.addEventListener('change', render);
  render();
})();
''';

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
        : '<track id="portuguese-track" kind="captions" src="${const HtmlEscape(HtmlEscapeMode.attribute).convert(captions.toString())}" srclang="pt-BR" label="Português">';
    final random = captions == null ? null : Random.secure();
    final nonce = random == null
        ? null
        : base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
    final captionPanel = captions == null
        ? ''
        : '<div id="caption-panel">'
              '<button id="caption-toggle" type="button" aria-controls="caption-text" aria-pressed="true">Ocultar legendas</button>'
              '<div id="caption-text" role="status" aria-live="polite" aria-label="Legendas em português"></div>'
              '</div><script nonce="$nonce">$_captionScript</script>';
    final scriptSource = nonce == null ? 'none' : 'nonce-$nonce';
    return '<!doctype html><html lang="pt-BR"><head>'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<meta http-equiv="Content-Security-Policy" content="default-src &#39;none&#39;; media-src https://$host; connect-src &#39;none&#39;; script-src &#39;$scriptSource&#39;; style-src &#39;unsafe-inline&#39;; object-src &#39;none&#39;; base-uri &#39;none&#39;">'
        '<style>html,body{margin:0;background:#111;color:white}'
        'video{display:block;width:100%;aspect-ratio:16/9;object-fit:contain}'
        '#caption-panel{padding:8px 12px;font:18px/1.35 sans-serif}'
        '#caption-toggle{min-height:44px;padding:8px 12px;font:inherit;color:white;background:#333;border:1px solid white;border-radius:6px}'
        '#caption-toggle:focus-visible{outline:3px solid #ffda45;outline-offset:2px}'
        '#caption-text{min-height:2.7em;max-height:6em;overflow-y:auto;white-space:pre-line;padding-top:6px}</style>'
        '</head><body><video id="lesson-video" controls playsinline preload="metadata">'
        '<source src="$source" type="video/mp4">$vtt'
        'Seu navegador não consegue reproduzir esta videoaula.'
        '</video>$captionPanel</body></html>';
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
              aspectRatio: widget.captions == null ? 16 / 9 : 1,
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
  bool _loadingLocalDocument = true;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 20), widget.onError);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(
        widget.captions == null
            ? JavaScriptMode.disabled
            : JavaScriptMode.unrestricted,
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // The base URL establishes same-origin MP4/VTT access only during
            // the initial local HTML load. No remote page may replace it.
            return _loadingLocalDocument &&
                    (request.url == 'about:blank' ||
                        request.url == 'https://ead.ipexdesenvolvimento.cloud/')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            _loadingLocalDocument = false;
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
