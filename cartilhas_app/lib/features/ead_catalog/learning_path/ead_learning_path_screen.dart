import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/cartilha.dart';
import '../../../screens/chat_experience_screen.dart';
import '../../courses/data/course_repository.dart';
import '../data/ead_catalog_repository.dart';
import 'ead_curriculum_repository.dart';
import 'ead_editorial_bridge_repository.dart';
import 'ead_mobile_lesson_screen.dart';
import 'ead_quiz_link_repository.dart';

typedef CurriculumLoader = Future<EadCurriculum> Function(EadCourse course);
typedef LocalCartilhaLoader = Future<List<Cartilha>> Function();

/// Site sequence is read-only. The local cartilha retains its own practice.
class EadLearningPathScreen extends StatefulWidget {
  const EadLearningPathScreen({
    super.key,
    required this.course,
    this.curriculumLoader,
    this.localCartilhaLoader,
    this.openCourse,
    this.quizUriLoader,
    this.lessonLoader,
  });

  final EadCourse course;
  final CurriculumLoader? curriculumLoader;
  final LocalCartilhaLoader? localCartilhaLoader;
  final Future<bool> Function(Uri uri)? openCourse;
  final Future<Uri> Function(int quizId)? quizUriLoader;
  final EadLessonLoader? lessonLoader;

  @override
  State<EadLearningPathScreen> createState() => _EadLearningPathScreenState();
}

class _EadLearningPathScreenState extends State<EadLearningPathScreen> {
  late Future<EadCurriculum> _curriculum;
  final EadEditorialBridgeRepository _editorial =
      EadEditorialBridgeRepository();

  static const _courseMapping = <int, String>{
    614: 'ia-cartilha',
    1298: 'agricultura-sustentavel',
    1307: 'atendimento-cliente',
    1314: 'audiovisual',
    1321: 'cooperativismo',
    1328: 'economia-lar',
    1335: 'educacao-financeira',
    1343: 'sim-sima',
    1356: 'saf',
  };

  String? get _localCourseId => _courseMapping[widget.course.id];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _curriculum = (widget.curriculumLoader ?? _editorial.fetch)(widget.course);
  }

  void _retry() => setState(_refresh);

  Future<void> _openPortal() async {
    var success = false;
    try {
      success =
          await (widget.openCourse?.call(widget.course.url) ??
              launchUrl(
                widget.course.url,
                mode: LaunchMode.externalApplication,
              ));
    } on Object {
      success = false;
    }
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o EAD. Tente novamente.'),
        ),
      );
    }
  }

  Future<void> _openQuiz(EadLesson lesson) async {
    try {
      // Always re-check publication and canonical permalink after every edit
      // in LearnPress. Do not retrieve questions, keys or assessment attempts.
      final uri =
          await (widget.quizUriLoader ??
              EadQuizLinkRepository().publishedQuizUri)(lesson.id);
      final opened =
          await (widget.openCourse?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && mounted) _info('Não foi possível abrir o quiz no EAD.');
    } on Object {
      if (mounted) {
        _info(
          'Quiz não está disponível no EAD. Confira a publicação e a inscrição.',
        );
      }
    }
  }

  Future<void> _openMobileLesson(EadLesson lesson) async {
    if (!lesson.mobileContent || lesson.type != 'lp_lesson') return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EadMobileLessonScreen(
          course: widget.course,
          lessonId: lesson.id,
          loader: widget.lessonLoader,
          openExternal: widget.openCourse,
        ),
      ),
    );
  }

  Future<void> _openNativeCartilha() async {
    final id = _localCourseId;
    if (id == null) return;
    try {
      final loader =
          widget.localCartilhaLoader ??
          () => CourseRepository(apiUrl: '').fetchAll();
      final courses = await loader();
      final matches = courses.where((course) => course.id == id);
      if (!mounted) return;
      if (matches.isEmpty) {
        _info('Cartilha indisponível neste aparelho.');
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatExperienceScreen(cartilha: matches.first),
        ),
      );
    } on Object {
      if (mounted) _info('Não foi possível abrir a cartilha.');
    }
  }

  void _info(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Percurso'),
        actions: [
          IconButton(
            tooltip: 'Atualizar percurso',
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<EadCurriculum>(
        future: _curriculum,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_outlined, size: 40),
                  const Text('Não foi possível consultar o percurso do EAD.'),
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }
          final journey = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              Text(widget.course.title, style: text.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Sequência de aulas do LearnPress. Cartilha, perguntas '
                'de prática e Tutor TDS continuam neste aplicativo.',
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${journey.sections.length} '
                    '${journey.sections.length == 1 ? 'seção' : 'seções'} · '
                    '${journey.lessonCount} '
                    '${journey.lessonCount == 1 ? 'item' : 'itens'} de aula · '
                    '${journey.videoCount} '
                    '${journey.videoCount == 1 ? 'aula' : 'aulas'} '
                    'em seções de vídeo',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openPortal,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Assistir videoaulas no EAD'),
              ),
              const SizedBox(height: 8),
              if (_localCourseId != null)
                OutlinedButton.icon(
                  key: const ValueKey('practice-native-cartilha'),
                  onPressed: _openNativeCartilha,
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text(
                    'Estudar cartilha, praticar e usar o Tutor',
                  ),
                )
              else
                const Text(
                  'Este curso ainda não possui cartilha nativa aprovada.',
                ),
              const SizedBox(height: 18),
              Text('Aulas na ordem do site', style: text.titleLarge),
              const SizedBox(height: 6),
              for (final section in journey.sections)
                Card(
                  child: ExpansionTile(
                    key: ValueKey('section-${section.id}'),
                    initiallyExpanded: true,
                    title: Text(section.title),
                    subtitle: Text(
                      '${section.lessons.length} '
                      '${section.lessons.length == 1 ? 'item' : 'itens'}',
                    ),
                    children: [
                      for (final lesson in section.lessons)
                        ListTile(
                          key: ValueKey('lesson-${lesson.id}'),
                          leading: Icon(
                            lesson.type == 'lp_quiz'
                                ? Icons.quiz_outlined
                                : lesson.isVideoCandidate
                                ? Icons.play_circle_outline
                                : Icons.menu_book_outlined,
                          ),
                          title: Text(lesson.title),
                          // No mobile opt-in means only a public syllabus:
                          // open the canonical course on the official EAD,
                          // never attempt to fetch protected lesson HTML.
                          onTap: lesson.type == 'lp_quiz'
                              ? () => _openQuiz(lesson)
                              : lesson.mobileContent
                              ? () => _openMobileLesson(lesson)
                              : _openPortal,
                          trailing:
                              lesson.type == 'lp_quiz' || !lesson.mobileContent
                              ? const Icon(Icons.open_in_new)
                              : const Icon(Icons.chevron_right),
                          subtitle: Text(
                            lesson.type == 'lp_quiz'
                                ? 'Abrir quiz publicado no EAD (sem transferir nota)'
                                : lesson.mobileContent
                                ? 'Ler conteúdo autorizado no Tutor TDS'
                                : 'Abrir curso no site EAD • '
                                      'aula não liberada para leitura no app',
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              const Text(
                'A prática local não equivale a prova formal. '
                'Matrícula, nota e certificado não são sincronizados por esta prévia.',
              ),
            ],
          );
        },
      ),
    );
  }
}
