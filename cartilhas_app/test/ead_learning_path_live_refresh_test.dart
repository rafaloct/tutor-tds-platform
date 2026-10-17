import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_curriculum_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_learning_path_screen.dart';
import 'package:cartilhas_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const course = EadCourse(
  id: 1356,
  slug: 'saf',
  title: 'Sistemas Agroflorestais',
);

EadCurriculum version(int revision) => EadCurriculum(
  course: course,
  sections: [
    EadSection(
      id: 80,
      title: revision > 1 ? 'Vídeos e revisão' : 'Assista em vídeo',
      lessons: [
        const EadLesson(
          id: 1425,
          title: 'SAF no Cerrado',
          type: 'lp_lesson',
          isVideoCandidate: true,
        ),
        if (revision == 2)
          const EadLesson(
            id: 9901,
            title: 'Quiz de revisão SAF',
            type: 'lp_quiz',
            isVideoCandidate: false,
          ),
        if (revision == 3)
          const EadLesson(
            id: 1703,
            title: 'Nova aula SAF',
            type: 'lp_lesson',
            isVideoCandidate: true,
          ),
      ],
    ),
  ],
);

void main() {
  testWidgets('publicação/remoção do quiz em LearnPress aparece sem novo APK', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var current = 1;
    var loads = 0;
    Uri? opened;
    final requested = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EadLearningPathScreen(
          course: course,
          curriculumLoader: (_) async {
            loads++;
            return version(current);
          },
          quizUriLoader: (id) async {
            requested.add(id);
            return Uri.parse(
              'https://ead.ipexdesenvolvimento.cloud/quizzes/revisao-saf/',
            );
          },
          openCourse: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quiz de revisão SAF'), findsNothing);
    current = 2;
    await tester.tap(find.byTooltip('Atualizar percurso'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz de revisão SAF'), findsOneWidget);
    expect(find.text('Vídeos e revisão'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lesson-9901')));
    await tester.pump();
    expect(requested, [9901]);
    expect(opened?.path, '/quizzes/revisao-saf/');
    current = 3;
    await tester.tap(find.byTooltip('Atualizar percurso'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz de revisão SAF'), findsNothing);
    expect(find.text('Nova aula SAF'), findsOneWidget);
    expect(loads, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro do quiz não apresenta resposta nem nota', (tester) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EadLearningPathScreen(
          course: course,
          curriculumLoader: (_) async => version(2),
          quizUriLoader: (_) async => throw const EadCurriculumException('401'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lesson-9901')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Quiz não está disponível'), findsOneWidget);
    expect(find.textContaining('gabarito'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
