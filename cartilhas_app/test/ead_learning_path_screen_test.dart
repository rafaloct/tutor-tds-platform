import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_curriculum_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_learning_path_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const course = EadCourse(
  id: 1356,
  slug: 'saf',
  title: 'Sistemas Agroflorestais',
);
const emptyCourse = EadCourse(
  id: 1709,
  slug: 'ia-processos-internos',
  title: 'IA interna',
);

EadCurriculum fixture(EadCourse forCourse) => EadCurriculum(
  course: forCourse,
  sections: const [
    EadSection(
      id: 72,
      title: 'O que é um SAF?',
      lessons: [
        EadLesson(
          id: 1357,
          title: 'O que é um SAF?',
          type: 'lp_lesson',
          isVideoCandidate: false,
        ),
      ],
    ),
    EadSection(
      id: 80,
      title: 'Assista em vídeo',
      lessons: [
        EadLesson(
          id: 1425,
          title: 'Aula 01 - SAF',
          type: 'lp_lesson',
          isVideoCandidate: true,
        ),
        EadLesson(
          id: 1426,
          title: 'Aula 02 - Prática',
          type: 'lp_lesson',
          isVideoCandidate: true,
        ),
      ],
    ),
  ],
);

void main() {
  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(480, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('curso SAF mostra vídeo, cartilha e prática sem importar prova', (
    tester,
  ) async {
    viewport(tester);
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: EadLearningPathScreen(
          course: course,
          curriculumLoader: (c) async => fixture(c),
          openCourse: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Percurso de aprendizagem'), findsOneWidget);
    expect(find.text('3 itens de aula', findRichText: true), findsNothing);
    expect(find.text('Aula 01 - SAF'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('practice-native-cartilha')),
      findsOneWidget,
    );
    await tester.tap(find.text('Assistir videoaulas no EAD'));
    await tester.pump();
    expect(
      opened!.toString(),
      'https://ead.ipexdesenvolvimento.cloud/courses/saf/',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('curso sem cartilha não fabrica tutor contextual', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EadLearningPathScreen(
          course: emptyCourse,
          curriculumLoader: (c) async =>
              EadCurriculum(course: c, sections: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ainda não possui cartilha'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('practice-native-cartilha')),
      findsNothing,
    );
  });

  testWidgets('falha de rede deixa o erro visível sem inventar aulas', (
    tester,
  ) async {
    viewport(tester);
    var online = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EadLearningPathScreen(
          course: course,
          curriculumLoader: (c) async {
            if (!online) throw const EadCurriculumException('indisponível');
            return fixture(c);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível consultar'), findsOneWidget);
    expect(find.text('Aula 01 - SAF'), findsNothing);
    online = true;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Aula 01 - SAF'), findsOneWidget);
  });
}
