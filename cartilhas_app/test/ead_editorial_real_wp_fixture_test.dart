import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_editorial_bridge_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_mobile_lesson_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// HTTP responses captured from a real, isolated WordPress 6.7.2 +
/// LearnPress 4.3.6 + TDS bridge installation. Posts are synthetic;
/// no student data, secrets, real enrollment or actual grades are present.
const syntheticCourse = EadCourse(
  id: 11,
  slug: 'saf-qa-sintetico',
  title: 'SAF – Curso sintético para QA',
);
const dir = 'test/fixtures/ead_editorial';

Future<Map<String, dynamic>> fixture(String name) async {
  final raw = await File('$dir/$name').readAsString();
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  test(
    'real WP/LearnPress curriculum JSON is accepted without client shims',
    () async {
      final wpPayload = await fixture('curriculum-wp672-lp436-synthetic.json');
      final revision = wpPayload['revision'] as String;
      final repo = EadEditorialBridgeRepository(
        get: (uri, headers) async {
          expect(uri.host, 'ead.ipexdesenvolvimento.cloud');
          expect(uri.path, endsWith('/courses/11/curriculum'));
          expect(headers['If-None-Match'], isNull);
          return http.Response.bytes(
            utf8.encode(jsonEncode(wpPayload)),
            200,
            headers: {'etag': '"$revision"'},
          );
        },
      );
      final result = await repo.fetch(syntheticCourse);
      expect(result.sections, hasLength(1));
      expect(result.lessonCount, 2);
      expect(result.videoCount, 1);
      final video = result.sections.single.lessons.first;
      expect(video.id, 12);
      expect(video.mobileContent, true);
      expect(video.youtubeId, 'FG14ksTaMCE');
      final quiz = result.sections.single.lessons.last;
      expect(quiz.id, 14);
      expect(quiz.type, 'lp_quiz');
      expect(quiz.mobileContent, false);
      expect(wpPayload.toString(), isNot(contains('gabarito')));
    },
  );

  test(
    'real WP/LearnPress lesson HTML is rendered as safe native text',
    () async {
      final wpPayload = await fixture('lesson-wp672-lp436-synthetic.json');
      final repo = EadEditorialBridgeRepository(
        get: (uri, headers) async {
          expect(uri.path, endsWith('/courses/11/lessons/12'));
          return http.Response.bytes(utf8.encode(jsonEncode(wpPayload)), 200);
        },
      );
      final lesson = await repo.lesson(syntheticCourse, 12);
      expect(lesson.youtubeId, 'FG14ksTaMCE');
      expect(lesson.contentHtml, isNot(contains('<script')));
      expect(lesson.contentHtml, isNot(contains('bad()')));
      expect(lesson.contentHtml, isNot(contains('[shortcode-secret')));
      final blocks = EadSafeHtmlBlocks.parse(lesson.contentHtml);
      expect(blocks.map((item) => item.kind), ['h2', 'p']);
      expect(blocks.map((item) => item.text), [
        'Como cultivar',
        'Texto atualizado na fonte LearnPress.',
      ]);
    },
  );

  test(
    'a revalidated real WP snapshot is reused only after HTTP 304',
    () async {
      final wpPayload = await fixture('curriculum-wp672-lp436-synthetic.json');
      final revision = wpPayload['revision'] as String;
      var attempts = 0;
      final repo = EadEditorialBridgeRepository(
        get: (_, headers) async {
          attempts++;
          if (attempts == 2) {
            expect(headers['If-None-Match'], '"$revision"');
            return http.Response('', 304);
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode(wpPayload)),
            200,
            headers: {'etag': '"$revision"'},
          );
        },
      );
      final original = await repo.fetch(syntheticCourse);
      final conditional = await repo.fetch(syntheticCourse);
      expect(identical(original, conditional), true);
      expect(attempts, 2);
    },
  );
}
