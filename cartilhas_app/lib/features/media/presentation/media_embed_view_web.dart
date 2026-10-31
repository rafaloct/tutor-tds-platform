// Player de mídia para Flutter Web: iframe srcdoc + postMessage.
// O HTML é o mesmo do webview nativo (buildSecureMediaHtml); os eventos
// chegam via window 'message' no lugar do canal TutorVideo do webview.
import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

int _viewSeq = 0;

class MediaEmbedView extends StatefulWidget {
  const MediaEmbedView({super.key, required this.html, required this.onMessage});
  final String html;
  final void Function(String message) onMessage;

  @override
  State<MediaEmbedView> createState() => _MediaEmbedViewState();
}

class _MediaEmbedViewState extends State<MediaEmbedView> {
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  StreamSubscription<web.MessageEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _viewType = 'tds-media-embed-${_viewSeq++}';
    _iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..srcdoc = widget.html.toJS
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000'
      ..allowFullscreen = true
      ..setAttribute('allow',
          'accelerometer; autoplay; encrypted-media; picture-in-picture');
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _iframe);
    _sub = web.EventStreamProviders.messageEvent.forTarget(web.window).listen(
        (event) {
      final data = event.data.dartify();
      if (data is String) widget.onMessage(data);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      HtmlElementView(viewType: _viewType);
}
