import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

/// Normaliza texto do Tutor para fala (TTS): remove sintaxe Markdown e links
/// em notação `[texto](url)` preservando o conteúdo legível. Chaves comuns e
/// demais caracteres passam intactos.
String tutorPlainText(String source) {
  final buffer = StringBuffer();
  for (final rawLine in source.split('\n')) {
    var line = rawLine;
    final heading = RegExp(r'^\s*#{1,6}\s+').firstMatch(line);
    if (heading != null) line = line.substring(heading.end);
    final bullet = RegExp(r'^\s*(?:[-*+]|\d+\.)\s+').firstMatch(line);
    if (bullet != null) line = line.substring(bullet.end);
    buffer.writeln(_stripInlineMarkdown(line));
  }
  return buffer.toString().trim();
}

String _stripInlineMarkdown(String text) {
  var out = text;
  out = out.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\((https?://[^\s\)]+|wa\.me/[^\s\)]+)\)'),
    (m) => m.group(1)!,
  );
  out = out.replaceAll('```', '');
  out = out.replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1)!);
  out = out.replaceAllMapped(
    RegExp(r'\*{3}(.+?)\*{3}|_{3}(.+?)_{3}'),
    (m) => m.group(1) ?? m.group(2) ?? '',
  );
  out = out.replaceAllMapped(
    RegExp(r'\*{2}(.+?)\*{2}|_{2}(.+?)_{2}'),
    (m) => m.group(1) ?? m.group(2) ?? '',
  );
  out = out.replaceAllMapped(
    RegExp(r'\*([^*\n]+)\*|_([^_\n]+)_'),
    (m) => m.group(1) ?? m.group(2) ?? '',
  );
  return out;
}

/// Texto de resposta do Tutor com ênfase Markdown básica e links que passam
/// por confirmação ([onLinkTap]) em vez de abrir direto.
class TutorMessageText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final ValueChanged<String>? onLinkTap;

  const TutorMessageText(this.text, {super.key, this.style, this.onLinkTap});

  @override
  State<TutorMessageText> createState() => _TutorMessageTextState();
}

class _TutorMessageTextState extends State<TutorMessageText> {
  static final _mdLinkRegex = RegExp(
    r'\[([^\]]+)\]\((https?://[^\s\)]+|wa\.me/[^\s\)]+)\)',
    caseSensitive: false,
  );
  static final _bareUrlRegex = RegExp(
    r'(https?://[^\s\)\]]+|wa\.me/[^\s\)\]]+)',
    caseSensitive: false,
  );
  static final _inlineRegex = RegExp(
    r'(\*{3}.+?\*{3}|_{3}.+?_{3}|\*{2}.+?\*{2}|_{2}.+?_{2}|\*[^*\n]+\*|_[^_\n]+_|`[^`]*`)',
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _openLink(String url) async {
    final fullUrl = url.startsWith('http') ? url : 'https://$url';
    final onLinkTap = widget.onLinkTap;
    if (onLinkTap != null) {
      onLinkTap(fullUrl);
      return;
    }
    try {
      await launchUrl(
        Uri.parse(fullUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // URL inválida ou app não instalado — ignorado de propósito
    }
  }

  TapGestureRecognizer _linkRecognizer(String url) {
    final rec = TapGestureRecognizer()..onTap = () => _openLink(url);
    _recognizers.add(rec);
    return rec;
  }

  TextStyle get _base =>
      widget.style ??
      const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5);

  TextStyle _linkStyle() => const TextStyle(
    color: Color(0xFF093AF4),
    decoration: TextDecoration.underline,
    decorationColor: Color(0xFF093AF4),
    fontWeight: FontWeight.w500,
  );

  List<InlineSpan> _inlineSpans(String text) {
    final spans = <InlineSpan>[];
    var rest = text;
    while (rest.isNotEmpty) {
      final linkMatch = _mdLinkRegex.firstMatch(rest);
      final urlMatch = _bareUrlRegex.firstMatch(rest);
      final styleMatch = _inlineRegex.firstMatch(rest);

      // Escolhe o token mais cedo; link Markdown tem prioridade sobre URL nua.
      RegExpMatch? first;
      var kind = 0; // 1=mdlink 2=url 3=inline style
      for (final entry in [
        (linkMatch, 1),
        (urlMatch, 2),
        (styleMatch, 3),
      ]) {
        final m = entry.$1;
        if (m != null && (first == null || m.start < first.start)) {
          first = m;
          kind = entry.$2;
        }
      }
      if (first == null) {
        spans.add(TextSpan(text: rest));
        break;
      }
      if (first.start > 0) {
        spans.add(TextSpan(text: rest.substring(0, first.start)));
      }
      switch (kind) {
        case 1:
          spans.add(
            TextSpan(
              text: first.group(1),
              style: _linkStyle(),
              recognizer: _linkRecognizer(first.group(2)!),
            ),
          );
          break;
        case 2:
          final matchText = first.group(0)!;
          final url = matchText.replaceAll(RegExp(r'[.,!?;:\)]+$'), '');
          spans.add(
            TextSpan(
              text: url,
              style: _linkStyle(),
              recognizer: _linkRecognizer(url),
            ),
          );
          final punctuation = matchText.substring(url.length);
          if (punctuation.isNotEmpty) spans.add(TextSpan(text: punctuation));
          rest = rest.substring(first.end);
          continue;
        default:
          final token = first.group(0)!;
          final inner = _stripMarkers(token);
          final style = _styleFor(token);
          spans.add(TextSpan(text: inner, style: style));
      }
      rest = rest.substring(first.end);
    }
    return spans;
  }

  String _stripMarkers(String token) {
    if (token.startsWith('`')) {
      return token.replaceAll('`', '');
    }
    final m = RegExp(
      r'^\*{3}(.+?)\*{3}$|^_{3}(.+?)_{3}$|^\*{2}(.+?)\*{2}$|^_{2}(.+?)_{2}$|^\*([^*\n]+)\*$|^_([^_\n]+)_$',
    ).firstMatch(token);
    if (m == null) return token;
    for (var i = 1; i <= 6; i++) {
      final g = m.group(i);
      if (g != null) return g;
    }
    return token;
  }

  TextStyle _styleFor(String token) {
    if (token.startsWith('`')) {
      return const TextStyle(fontFamily: 'monospace');
    }
    if (token.startsWith('***') || token.startsWith('___')) {
      return const TextStyle(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      );
    }
    if (token.startsWith('**') || token.startsWith('__')) {
      return const TextStyle(fontWeight: FontWeight.bold);
    }
    return const TextStyle(fontStyle: FontStyle.italic);
  }

  List<InlineSpan> _buildSpans() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    final lines = widget.text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (line.trim().isEmpty) {
        if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
        continue;
      }
      var heading = false;
      final headingMatch = RegExp(r'^\s*#{1,6}\s+').firstMatch(line);
      if (headingMatch != null) {
        heading = true;
        line = line.substring(headingMatch.end);
      }
      final bulletMatch = RegExp(r'^\s*(?:[-*+]|\d+\.)\s+').firstMatch(line);
      if (bulletMatch != null) {
        spans.add(const TextSpan(text: '• '));
        line = line.substring(bulletMatch.end);
      }
      for (final span in _inlineSpans(line)) {
        if (heading && span is TextSpan) {
          spans.add(
            TextSpan(
              text: span.text,
              style: (span.style ?? const TextStyle()).merge(
                const TextStyle(fontWeight: FontWeight.bold),
              ),
              recognizer: span.recognizer,
              children: span.children,
            ),
          );
        } else {
          spans.add(span);
        }
      }
      if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(style: _base, children: _buildSpans()));
  }
}
