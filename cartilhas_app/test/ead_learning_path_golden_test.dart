import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_curriculum_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_learning_path_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Static visual contract for review. The course names/IDs are a test fixture,
/// not evidence of live course content or a Play Store screenshot.
void main() {
  testWidgets('SAF curriculum preview screenshot (synthetic fixture)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(450, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const course = EadCourse(
      id: 1356,
      slug: 'saf',
      title: 'Sistemas Agroflorestais',
    );
    final data = EadCurriculum(
      course: course,
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
              title: 'Aula 01 - O que é um Sistema Agroflorestal',
              type: 'lp_lesson',
              isVideoCandidate: true,
            ),
            EadLesson(
              id: 1426,
              title: 'Aula 02 - Benefícios do SAF',
              type: 'lp_lesson',
              isVideoCandidate: true,
            ),
          ],
        ),
      ],
    );

    await (FontLoader(
      'Poppins',
    )..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))).load();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.green,
          fontFamily: 'Poppins',
        ),
        home: EadLearningPathScreen(
          course: course,
          curriculumLoader: (_) async => data,
          openCourse: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(EadLearningPathScreen),
      matchesGoldenFile('goldens/ead_saf_learning_path_preview.png'),
    );
  });
}
