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
  const report = event => IpexMediaEvents.postMessage(event);
  video.addEventListener('loadedmetadata', () => report('mp4_metadata'));
  video.addEventListener('playing', () => report('mp4_playing'));
  video.addEventListener('waiting', () => report('mp4_waiting'));
  video.addEventListener('stalled', () => report('mp4_stalled'));
  video.addEventListener('pause', () => report('mp4_paused'));
  video.addEventListener('error', () => report('mp4_error'));
  trackElement.addEventListener('load', () => report('vtt_loaded'));
  trackElement.addEventListener('error', () => report('vtt_error'));

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
    this.onMediaEvent,
    this.onController,
  });

  final Uri video;
  final Uri? captions;
  final String lessonTitle;
  final Future<bool> Function(Uri)? openExternal;
  final Widget Function(Uri, Uri?, VoidCallback, VoidCallback)? playerFactory;
  @visibleForTesting
  final ValueChanged<String>? onMediaEvent;
  @visibleForTesting
  final ValueChanged<WebViewController>? onController;

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
                    onMediaEvent: widget.onMediaEvent,
                    onController: widget.onController,
                  ),
            ),
          if (valid && !_failed && !_ready)
            const LinearProgressIndicator(
              semanticsLabel: 'Carregando videoaula do IPEX',
            ),
          if (!valid || _failed)
            const Text('Vídeo indisponível. Você pode tentar pelo site EAD.'),
          if (valid && _failed)
            TextButton(
              onPressed: () => setState(() {
                _failed = false;
                _ready = false;
              }),
              child: const Text('Tentar novamente'),
            ),
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
    this.onMediaEvent,
    this.onController,
  });
  final Uri video;
  final Uri? captions;
  final VoidCallback onReady;
  final VoidCallback onError;
  final ValueChanged<String>? onMediaEvent;
  final ValueChanged<WebViewController>? onController;

  @override
  State<_IpexWebView> createState() => _IpexWebViewState();
}

class _IpexWebViewState extends State<_IpexWebView> {
  WebViewController? _controller;
  IpexWebViewDeadline? _timeout;
  IpexWebViewDeadline? _nativeTimeout;
  bool _loadingLocalDocument = true;
  bool _htmlLoadRequested = false;
  bool _completed = false;
  final Stopwatch _elapsed = Stopwatch()..start();

  void _trace(String stage) {
    // Stage and elapsed time only: never log media URLs or lesson data.
    debugPrint(
      'IPEX_WEBVIEW stage=$stage elapsed_ms=${_elapsed.elapsedMilliseconds}',
    );
  }

  void _fail(String stage) {
    if (!mounted || _completed) return;
    _completed = true;
    _timeout?.cancel();
    _nativeTimeout?.cancel();
    _trace(stage);
    widget.onError();
  }

  @override
  void initState() {
    super.initState();
    _trace('native_start');
    _nativeTimeout = IpexWebViewDeadline(
      const Duration(minutes: 2),
      () => _fail('native_setup_timeout'),
    )..start();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final controller = WebViewController();
      _trace('controller_created');
      await controller.setJavaScriptMode(
        widget.captions == null
            ? JavaScriptMode.disabled
            : JavaScriptMode.unrestricted,
      );
      _trace('javascript_configured');
      if (widget.captions != null) {
        await controller.addJavaScriptChannel(
          'IpexMediaEvents',
          onMessageReceived: (message) {
            switch (message.message) {
              case 'mp4_metadata':
              case 'mp4_playing':
              case 'mp4_waiting':
              case 'mp4_stalled':
              case 'mp4_paused':
              case 'mp4_error':
              case 'vtt_loaded':
              case 'vtt_error':
                _trace(message.message);
                widget.onMediaEvent?.call(message.message);
            }
          },
        );
        _trace('media_observer_configured');
      }
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // The base URL establishes same-origin MP4/VTT access only during
            // the initial local HTML load. No remote page may replace it.
            final allowed =
                _loadingLocalDocument &&
                (request.url == 'about:blank' ||
                    request.url == 'https://ead.ipexdesenvolvimento.cloud/');
            _trace(allowed ? 'navigation_allowed' : 'navigation_blocked');
            return allowed
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageStarted: (_) => _trace('html_page_started'),
          onProgress: (progress) {
            if (progress == 100) _trace('html_progress_100');
          },
          onPageFinished: (url) {
            if (!_htmlLoadRequested ||
                url != 'https://ead.ipexdesenvolvimento.cloud/') {
              _trace('html_page_finished_unexpected');
              return;
            }
            _loadingLocalDocument = false;
            _timeout?.cancel();
            if (!mounted || _completed) return;
            _completed = true;
            _trace('html_page_finished');
            widget.onReady(); // HTML loaded, NOT proof of playback.
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) {
              _trace('subresource_error_${error.errorCode}');
              return;
            }
            _fail('main_frame_error_${error.errorCode}');
          },
          onHttpError: (_) => _trace('http_error'),
        ),
      );
      _trace('delegate_configured');
      _nativeTimeout?.cancel();
      if (!mounted || _completed) return;
      setState(() => _controller = controller);
      widget.onController?.call(controller);
      _htmlLoadRequested = true;
      _trace('html_load_requested');
      // Native controller startup is a separate phase. Its cold-start latency
      // must not consume the local document's 20-second load budget.
      _timeout = IpexWebViewDeadline(
        const Duration(seconds: 20),
        () => _fail('html_load_timeout'),
      )..start();
      await controller.loadHtmlString(
        EadIpexVideoPolicy.document(widget.video, widget.captions),
        baseUrl: 'https://ead.ipexdesenvolvimento.cloud/',
      );
      _trace('html_load_call_completed');
    } on Object {
      _fail(
        _htmlLoadRequested ? 'html_load_exception' : 'native_setup_exception',
      );
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _nativeTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _controller == null
      ? const SizedBox.shrink()
      : WebViewWidget(controller: _controller!);
}

/// The HTML load budget begins only after the native WebView is configured.
@visibleForTesting
class IpexWebViewDeadline {
  IpexWebViewDeadline(this.duration, this.onTimeout);

  final Duration duration;
  final VoidCallback onTimeout;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer(duration, onTimeout);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
