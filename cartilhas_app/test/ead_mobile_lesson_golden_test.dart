import 'dart:io';
import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_editorial_bridge_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_mobile_lesson_screen.dart';
import 'package:cartilhas_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Synthetic editorial fixture, not a screenshot of installed Android build.
void main() {
  testWidgets('SAF authorized WordPress text with native institutional theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(450, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'Poppins',
    )..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))).load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EadMobileLessonScreen(
          course: const EadCourse(id: 1356, slug: 'saf', title: 'SAF'),
          lessonId: 1425,
          loader: (_, _) async => const EadEditorialLesson(
            courseId: 1356,
            lessonId: 1425,
            title: 'Aula 01 - O que é um SAF?',
            contentHtml:
                '<h2>Como funciona um Sistema Agroflorestal</h2>'
                '<p>O SAF integra espécies de diferentes portes em um '
                'planejamento diversificado.</p>'
                '<p>Material ilustrativo sujeito à revisão editorial.</p>'
                '<ul><li>Observar o terreno</li><li>Planejar o plantio</li></ul>',
            revision:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            youtubeId: 'FG14ksTaMCE',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(EadMobileLessonScreen),
      matchesGoldenFile(
        Platform.isLinux
            ? 'goldens/linux/ead_authorized_lesson_blue.png'
            : 'goldens/ead_authorized_lesson_blue.png',
      ),
    );
  });
}
