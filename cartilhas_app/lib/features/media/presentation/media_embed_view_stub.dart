import 'package:flutter/material.dart';

/// Stub para plataformas nativas — a UI real usa WebViewWidget.
/// Mantém a mesma API da implementação web (import condicional).
class MediaEmbedView extends StatelessWidget {
  const MediaEmbedView({
    super.key,
    required this.html,
    required this.onMessage,
  });

  final String html;
  final void Function(String message) onMessage;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
