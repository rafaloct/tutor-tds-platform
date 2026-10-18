import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/ead_catalog_repository.dart';
import 'ead_editorial_bridge_repository.dart';
import 'ead_youtube_player_screen.dart';

typedef EadLessonLoader =
    Future<EadEditorialLesson> Function(EadCourse course, int lessonId);

/// Native, accessible rendering of the deliberately limited WordPress
/// formatting subset. Scripts, widgets and student-specific content are not run.
class EadMobileLessonScreen extends StatefulWidget {
  const EadMobileLessonScreen({
    super.key,
    required this.course,
    required this.lessonId,
    this.loader,
    this.openExternal,
    this.videoViewFactory,
  });

  final EadCourse course;
  final int lessonId;
  final EadLessonLoader? loader;
  final EadVideoViewFactory? videoViewFactory;
  final Future<bool> Function(Uri url)? openExternal;

  @override
  State<EadMobileLessonScreen> createState() => _EadMobileLessonScreenState();
}

class _EadMobileLessonScreenState extends State<EadMobileLessonScreen> {
  late Future<EadEditorialLesson> _detail;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _detail = (widget.loader ?? EadEditorialBridgeRepository().lesson)(
      widget.course,
      widget.lessonId,
    );
  }

  void _retry() => setState(_refresh);

  Future<void> _open(Uri uri) async {
    bool launched = false;
    try {
      launched =
          await (widget.openExternal?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } on Object {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o endereço.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aula do EAD'),
        actions: [
          IconButton(
            onPressed: _retry,
            tooltip: 'Atualizar aula do LearnPress',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<EadEditorialLesson>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'O conteúdo integral desta aula não está disponível '
                      'publicamente no aplicativo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                    TextButton(
                      onPressed: () => _open(widget.course.url),
                      child: const Text('Continuar pelo site EAD'),
                    ),
                  ],
                ),
              ),
            );
          }
          final lesson = snapshot.data!;
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 36),
            children: [
              Text(lesson.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Texto publicado e liberado pelo LearnPress. '
                'Atualize para consultar revisões do site.',
              ),
              const SizedBox(height: 20),
              ...EadSafeHtmlBlocks.parse(lesson.contentHtml).map((block) {
                final style = switch (block.kind) {
                  'h2' => theme.textTheme.titleLarge,
                  'h3' => theme.textTheme.titleMedium,
                  'h4' => theme.textTheme.titleSmall,
                  'blockquote' => theme.textTheme.bodyMedium,
                  _ => theme.textTheme.bodyLarge,
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SelectableText(
                    block.kind == 'li' ? '• ${block.text}' : block.text,
                    style: style,
                  ),
                );
              }),
              if (EadYoutubePolicy.validId(lesson.youtubeId)) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EadYoutubePlayerScreen(
                        videoId: lesson.youtubeId!,
                        lessonTitle: lesson.title,
                        courseTitle: widget.course.title,
                        openExternal: widget.openExternal,
                        viewFactory: widget.videoViewFactory,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Assistir vídeo aprovado'),
                ),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => _open(widget.course.url),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir curso completo no EAD'),
              ),
              const SizedBox(height: 14),
              Text(
                'Fonte: LearnPress • revisão editorial '
                '${lesson.revision.substring(0, 8)}. '
                'Matrícula, prova e certificado seguem suas regras no EAD.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class EadTextBlock {
  const EadTextBlock(this.kind, this.text);
  final String kind;
  final String text;
}

/// WordPress bridge only emits p/h2-h4/li/blockquote/inline strong/em/a.
/// This display intentionally does not execute shortcodes, embeds or links.
class EadSafeHtmlBlocks {
  static final _blocks = RegExp(
    r'<(h2|h3|h4|p|li|blockquote)\b[^>]*>([\s\S]*?)</\1>',
    caseSensitive: false,
  );
  static final _tags = RegExp(r'<[^>]*>');
  static final _numeric = RegExp(r'&#(x[0-9a-fA-F]+|[0-9]+);');

  static List<EadTextBlock> parse(String html) {
    if (html.length > 250000) return const [];
    final blocks = <EadTextBlock>[];
    for (final match in _blocks.allMatches(html)) {
      final kind = match.group(1)!.toLowerCase();
      final body = _plain(match.group(2)!);
      if (body.isNotEmpty) blocks.add(EadTextBlock(kind, body));
    }
    if (blocks.isEmpty) {
      final text = _plain(html);
      if (text.isNotEmpty) blocks.add(EadTextBlock('p', text));
    }
    return List.unmodifiable(blocks);
  }

  static String _plain(String source) {
    final withoutTags = source.replaceAll(_tags, '');
    final decoded = withoutTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#039;', "'");
    return decoded
        .replaceAllMapped(_numeric, (m) {
          final token = m.group(1)!;
          final number = token.startsWith('x')
              ? int.tryParse(token.substring(1), radix: 16)
              : int.tryParse(token);
          return number != null &&
                  number > 0 &&
                  number <= 0x10ffff &&
                  !(number >= 0xd800 && number <= 0xdfff)
              ? String.fromCharCode(number)
              : '';
        })
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
