// Player de mídia para Flutter Web: iframe srcdoc + postMessage.
// O HTML é o mesmo do webview nativo (buildSecureMediaHtml); os eventos
// chegam via window 'message' no lugar do canal TutorVideo do webview.
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

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
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _viewType = 'tds-media-embed-${_viewSeq++}';
    _iframe = html.IFrameElement()
      ..srcdoc = widget.html
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000'
      ..allowFullscreen = true
      ..setAttribute('allow',
          'accelerometer; autoplay; encrypted-media; picture-in-picture');
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _iframe);
    _sub = html.window.onMessage.listen((event) {
      if (event.data is String) widget.onMessage(event.data as String);
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
