import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

/// Renderiza texto com URLs tocáveis. Mantém recognizers limpos via StatefulWidget.
class LinkifyText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const LinkifyText(this.text, {super.key, this.style});

  @override
  State<LinkifyText> createState() => _LinkifyTextState();
}

class _LinkifyTextState extends State<LinkifyText> {
  static final _urlRegex = RegExp(
    r'(https?://[^\s\)\]]+|wa\.me/[^\s\)\]]+)',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _buildSpans() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final spans = <InlineSpan>[];
    int last = 0;

    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }

      // Remove pontuação final que não faz parte da URL
      final raw = match.group(0)!;
      final url = raw.replaceAll(RegExp(r'[.,!?;:\)]+$'), '');
      final fullUrl = url.startsWith('http') ? url : 'https://$url';

      final rec = TapGestureRecognizer()
        ..onTap = () async {
          try {
            await launchUrl(
              Uri.parse(fullUrl),
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {
            // Ignora silenciosamente — URL inválida ou app não instalado
          }
        };
      _recognizers.add(rec);

      spans.add(
        TextSpan(
          text: url,
          recognizer: rec,
          style: const TextStyle(
            color: Color(0xFF093AF4),
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFF093AF4),
            fontWeight: FontWeight.w500,
          ),
        ),
      );

      last = match.start + url.length;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base =
        widget.style ??
        const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5);
    return Text.rich(TextSpan(style: base, children: _buildSpans()));
  }
}
