import 'dart:convert';

import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_curriculum_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_editorial_bridge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const course = EadCourse(id: 1356, slug: 'saf', title: 'SAF');
const revisionA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const revisionB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

http.Response editorial({
  String revision = revisionA,
  String title = 'Aula SAF',
  bool public = true,
  Object? media,
  int code = 200,
}) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'schema_version': 1,
      'authority': 'learnpress',
      'course_id': 1356,
      'title': 'SAF',
      'revision': revision,
      'sections': [
        {
          'id': 80,
          'title': 'Videoaulas',
          'items': [
            {
              'id': 1425,
              'type': 'lp_lesson',
              'title': title,
              'revision': '2026-10-17 20:22:44',
              'mobile_content': public,
              'media': media,
            },
            {
              'id': 640,
              'type': 'lp_quiz',
              'title': 'Quiz publicado',
              'revision': '2026-10-17 20:22:44',
            },
          ],
        },
      ],
    }),
  ),
  code,
  headers: {'etag': '"$revision"'},
);

void main() {
  test('currículo opt-in mostra a lição e quiz ao vivo sem gabarito', () async {
    Uri? requested;
    final repo = EadEditorialBridgeRepository(
      get: (uri, headers) async {
        requested = uri;
        return editorial(
          media: {'provider': 'youtube', 'video_id': 'FG14ksTaMCE'},
        );
      },
    );
    final c = await repo.fetch(course);
    expect(c.lessonCount, 2);
    expect(c.videoCount, 1);
    expect(c.sections[0].lessons[0].mobileContent, true);
    expect(c.sections[0].lessons[0].youtubeId, 'FG14ksTaMCE');
    expect(c.sections[0].lessons[1].type, 'lp_quiz');
    expect(requested!.host, 'ead.ipexdesenvolvimento.cloud');
    expect(requested!.path, '/wp-json/tds-learning/v1/courses/1356/curriculum');
    expect(requested!.query, isEmpty);
  });

  test('ETag 304 usa apenas o objeto já validado na memória', () async {
    final sent = <Map<String, String>>[];
    var calls = 0;
    final repo = EadEditorialBridgeRepository(
      get: (uri, headers) async {
        sent.add(headers);
        calls++;
        if (calls == 2) return http.Response('', 304);
        return editorial();
      },
    );
    final first = await repo.fetch(course);
    final second = await repo.fetch(course);
    expect(identical(first, second), true);
    expect(sent.first.containsKey('If-None-Match'), false);
    expect(sent.last['If-None-Match'], '"$revisionA"');
  });

  test('edição WordPress muda conteúdo após refetch sem build', () async {
    var revision = revisionA;
    final repo = EadEditorialBridgeRepository(
      get: (uri, headers) async => editorial(
        revision: revision,
        title: revision == revisionA ? 'Aula SAF' : 'Aula SAF editada no site',
      ),
    );
    expect(
      (await repo.fetch(course)).sections.first.lessons.first.title,
      'Aula SAF',
    );
    revision = revisionB;
    expect(
      (await repo.fetch(course)).sections.first.lessons.first.title,
      'Aula SAF editada no site',
    );
  });

  test(
    'plugin ainda não instalado: usa grade oficial antiga, sem permissão inventada',
    () async {
      final fallback = EadCurriculumRepository(
        httpGet: (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'id': 1356,
              'sections': [
                {
                  'id': 80,
                  'title': 'Assista em vídeo',
                  'items': [
                    {'id': 1425, 'title': 'Vídeo SAF', 'type': 'lp_lesson'},
                  ],
                },
              ],
            }),
          ),
          200,
        ),
      );
      final repo = EadEditorialBridgeRepository(
        get: (_, _) async => http.Response('Not Found', 404),
        fallback: fallback,
      );
      final result = await repo.fetch(course);
      expect(result.videoCount, 1);
      expect(result.sections.first.lessons.first.mobileContent, false);
      expect(result.sections.first.lessons.first.youtubeId, isNull);
    },
  );

  test('401/403 não autorizam fallback para conteúdo restrito', () async {
    for (final code in [401, 403]) {
      final repo = EadEditorialBridgeRepository(
        get: (_, _) async => http.Response('Forbidden', code),
      );
      expect(repo.fetch(course), throwsA(isA<EadCurriculumException>()));
    }
  });

  test('revision errada, vídeo inválido e post privado não passam', () async {
    final badVideo = EadEditorialBridgeRepository(
      get: (_, _) async =>
          editorial(media: {'provider': 'youtube', 'video_id': 'bad'}),
    );
    await expectLater(
      badVideo.fetch(course),
      throwsA(isA<EadCurriculumException>()),
    );
    final noRelease = EadEditorialBridgeRepository(
      get: (_, _) async => editorial(
        media: {'provider': 'youtube', 'video_id': 'FG14ksTaMCE'},
        public: false,
      ),
    );
    await expectLater(
      noRelease.fetch(course),
      throwsA(isA<EadCurriculumException>()),
    );
    final badEtag = EadEditorialBridgeRepository(
      get: (_, _) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'schema_version': 1,
            'authority': 'learnpress',
            'course_id': 1356,
            'revision': revisionA,
            'sections': [],
          }),
        ),
        200,
        headers: {'etag': '"invalid"'},
      ),
    );
    await expectLater(
      badEtag.fetch(course),
      throwsA(isA<EadCurriculumException>()),
    );
  });

  test(
    'aula publicada retorna texto e YouTube previamente liberados',
    () async {
      final repo = EadEditorialBridgeRepository(
        get: (uri, headers) async {
          expect(
            uri.path,
            '/wp-json/tds-learning/v1/courses/1356/lessons/1425',
          );
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'schema_version': 1,
                'authority': 'learnpress',
                'course_id': 1356,
                'lesson_id': 1425,
                'title': 'Agroecologia',
                'revision': revisionA,
                'content_html': '<h2>Agroecologia</h2><p>Texto autorizado.</p>',
                'media': {'provider': 'youtube', 'video_id': 'FG14ksTaMCE'},
              }),
            ),
            200,
          );
        },
      );
      final data = await repo.lesson(course, 1425);
      expect(data.contentHtml, contains('<h2>Agroecologia</h2>'));
      expect(data.youtubeId, 'FG14ksTaMCE');
    },
  );

  test('aula 404, script HTML e host de mídia falso são rejeitados', () async {
    final absent = EadEditorialBridgeRepository(
      get: (_, _) async => http.Response('Not Found', 404),
    );
    await expectLater(
      absent.lesson(course, 1425),
      throwsA(isA<EadCurriculumException>()),
    );
    final html = EadEditorialBridgeRepository(
      get: (_, _) async => http.Response(
        jsonEncode({
          'schema_version': 1,
          'authority': 'learnpress',
          'course_id': 1356,
          'lesson_id': 1425,
          'title': 'Aula',
          'revision': revisionA,
          'content_html': '<script>alert(1)</script>',
          'media': null,
        }),
        200,
      ),
    );
    await expectLater(
      html.lesson(course, 1425),
      throwsA(isA<EadCurriculumException>()),
    );
    final maliciousMedia = EadEditorialBridgeRepository(
      get: (_, _) async => editorial(
        media: {
          'provider': 'youtube',
          'video_id': 'FG14ksTaMCE',
          'poster_url': 'https://example.org/wp-content/uploads/poster.jpg',
        },
      ),
    );
    await expectLater(
      maliciousMedia.fetch(course),
      throwsA(isA<EadCurriculumException>()),
    );
  });
}
