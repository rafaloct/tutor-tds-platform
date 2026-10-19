import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_curriculum_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_editorial_bridge_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_learning_path_screen.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_mobile_lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _course = EadCourse(
  id: 1298,
  slug: 'agricultura-sustentavel',
  title: 'Agricultura Sustentável',
);

EadCurriculum _courseWithLesson({required bool mobileContent}) => EadCurriculum(
  course: _course,
  sections: [
    EadSection(
      id: 29,
      title: 'Boas-vindas',
      lessons: [
        EadLesson(
          id: 1299,
          title: 'Boas-vindas',
          type: 'lp_lesson',
          isVideoCandidate: false,
          mobileContent: mobileContent,
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

  testWidgets('aula sem opt-in abre somente o curso canônico no EAD', (
    tester,
  ) async {
    viewport(tester);
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: EadLearningPathScreen(
          course: _course,
          curriculumLoader: (_) async =>
              _courseWithLesson(mobileContent: false),
          openCourse: (uri) async {
            opened = uri;
            return true;
          },
          lessonLoader: (_, _) async =>
              throw StateError('conteúdo privado nunca deve ser solicitado'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('lesson-1299'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('não liberada para leitura no app'),
      findsOneWidget,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(opened, _course.url);
    expect(opened!.scheme, 'https');
    expect(opened!.host, EadCatalogRepository.host);
    expect(find.byType(EadMobileLessonScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aula explicitamente liberada permanece nativa', (tester) async {
    viewport(tester);
    Uri? opened;
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EadLearningPathScreen(
          course: _course,
          curriculumLoader: (_) async => _courseWithLesson(mobileContent: true),
          openCourse: (uri) async {
            opened = uri;
            return true;
          },
          lessonLoader: (c, lessonId) async {
            reads++;
            expect(c.id, _course.id);
            expect(lessonId, 1299);
            return const EadEditorialLesson(
              courseId: 1298,
              lessonId: 1299,
              title: 'Boas-vindas',
              contentHtml:
                  '<h2>Conteúdo autorizado</h2><p>Material editorial.</p>',
              revision:
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('lesson-1299'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(EadMobileLessonScreen), findsOneWidget);
    expect(find.text('Conteúdo autorizado'), findsOneWidget);
    expect(reads, 1);
    expect(opened, isNull);
    expect(tester.takeException(), isNull);
  });
}
