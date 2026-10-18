import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Platform seam: only readiness/failure, never playback or academic events.
typedef EadVideoViewFactory =
    Widget Function(String videoId, VoidCallback onReady, VoidCallback onError);

class EadYoutubePolicy {
  static bool validId(String? id) =>
      id != null &&
      id.length == 11 &&
      RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id);

  // Mirrors the existing Android applicationId/build-type suffix; no secret.
  static String get appReferer {
    const isolated = bool.fromEnvironment('DYNAMIC_QA_ISOLATED_PACKAGE');
    const runId = String.fromEnvironment('DYNAMIC_QA_RUN_ID');
    final suffix = kDebugMode
        ? (isolated && RegExp(r'^[a-f0-9]{32}$').hasMatch(runId)
              ? '.dev.dynamicqa.r$runId'
              : '.dev')
        : '';
    return 'https://com.tutortds_cartilhas$suffix/';
  }

  static Uri embed(String id) {
    if (!validId(id)) throw ArgumentError.value(id, 'videoId');
    return Uri.https('www.youtube-nocookie.com', '/embed/$id', {
      'autoplay': '0',
      'playsinline': '1',
      'cc_load_policy': '1',
      'rel': '0',
    });
  }

  static Uri external(String id) {
    if (!validId(id)) throw ArgumentError.value(id, 'videoId');
    return Uri.https('www.youtube.com', '/watch', {'v': id});
  }

  // Applies to main frame AND subframe navigations. Network subresources are
  // managed by YouTube/WebView; this is not a network request interceptor.
  static bool allows(String url, String id) {
    if (!validId(id)) return false;
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        !uri.hasFragment &&
        uri.host == 'www.youtube-nocookie.com' &&
        uri.path == '/embed/$id' &&
        uri.query == embed(id).query &&
        // Reject even aliases normalized by Uri (e.g. explicit default port).
        url == embed(id).toString();
  }
}

/// Public opt-in editorial playback only. No MediaItem, tracker or persistence.
class EadYoutubePlayerScreen extends StatefulWidget {
  const EadYoutubePlayerScreen({
    super.key,
    required this.videoId,
    required this.lessonTitle,
    required this.courseTitle,
    this.openExternal,
    this.viewFactory,
  });

  final String videoId;
  final String lessonTitle;
  final String courseTitle;
  final Future<bool> Function(Uri)? openExternal;
  final EadVideoViewFactory? viewFactory;

  @override
  State<EadYoutubePlayerScreen> createState() => _EadYoutubePlayerScreenState();
}

class _EadYoutubePlayerScreenState extends State<EadYoutubePlayerScreen> {
  bool _loading = true;
  bool _failed = false;

  void _ready() {
    if (mounted && !_failed) setState(() => _loading = false);
  }

  void _error() {
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _external() async {
    var opened = false;
    try {
      final url = EadYoutubePolicy.external(widget.videoId);
      opened =
          await (widget.openExternal?.call(url) ??
              launchUrl(url, mode: LaunchMode.externalApplication));
    } on Object {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o YouTube.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = EadYoutubePolicy.validId(widget.videoId);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('Vídeo da aula'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.courseTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            widget.lessonTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (valid && !_failed)
            AspectRatio(
              aspectRatio: 16 / 9,
              child:
                  widget.viewFactory?.call(widget.videoId, _ready, _error) ??
                  _YoutubeWebView(
                    videoId: widget.videoId,
                    onReady: _ready,
                    onError: _error,
                  ),
            ),
          if (valid && _loading)
            const LinearProgressIndicator(semanticsLabel: 'Carregando vídeo'),
          if (_failed || !valid)
            Semantics(
              liveRegion: true,
              child: Text(
                'Vídeo indisponível. Verifique sua conexão. '
                'Você pode voltar à aula ou tentar pelo YouTube.',
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Reprodução online, com controles do YouTube. '
            'Legendas dependem das trilhas disponíveis no vídeo. '
            'Assistir não registra conclusão, nota, presença ou certificado.',
          ),
          if (valid)
            OutlinedButton.icon(
              onPressed: _external,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir no YouTube'),
            ),
        ],
      ),
    );
  }
}

class _YoutubeWebView extends StatefulWidget {
  const _YoutubeWebView({
    required this.videoId,
    required this.onReady,
    required this.onError,
  });
  final String videoId;
  final VoidCallback onReady;
  final VoidCallback onError;

  @override
  State<_YoutubeWebView> createState() => _YoutubeWebViewState();
}

class _YoutubeWebViewState extends State<_YoutubeWebView> {
  WebViewController? _controller;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 20), widget.onError);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              EadYoutubePolicy.allows(request.url, widget.videoId)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) {
            _timeout?.cancel();
            // Document loaded is not evidence that playback succeeded.
            widget.onReady();
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
      await controller.loadRequest(
        EadYoutubePolicy.embed(widget.videoId),
        headers: {'Referer': EadYoutubePolicy.appReferer},
      );
    } on Object {
      _timeout?.cancel();
      // Delay callback until after the parent's build (platform may be absent).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onError();
      });
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _controller == null
      ? const SizedBox.expand()
      : WebViewWidget(controller: _controller!);
}
