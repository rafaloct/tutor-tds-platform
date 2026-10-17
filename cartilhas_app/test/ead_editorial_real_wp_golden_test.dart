import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_editorial_bridge_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_mobile_lesson_screen.dart';
import 'package:cartilhas_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Real HTTP JSON fixture from synthetic WordPress 6.7.2 + LearnPress 4.3.6.
/// This is a Flutter golden, NOT an Android screenshot or a real student's page.
void main() {
  testWidgets('real WP sandbox lesson JSON renders with blue official theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(450, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'Poppins',
    )..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))).load();

    final source =
        jsonDecode(
              File(
                'test/fixtures/ead_editorial/lesson-wp672-lp436-synthetic.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    const course = EadCourse(
      id: 11,
      slug: 'saf-qa-sintetico',
      title: 'SAF – Curso sintético para QA',
    );
    final repo = EadEditorialBridgeRepository(
      get: (uri, headers) async {
        expect(uri.host, 'ead.ipexdesenvolvimento.cloud');
        return http.Response.bytes(utf8.encode(jsonEncode(source)), 200);
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EadMobileLessonScreen(
          course: course,
          lessonId: 12,
          loader: repo.lesson,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(EadMobileLessonScreen),
      matchesGoldenFile('goldens/ead_wp_synthetic_real_http_blue.png'),
    );
  });
}
