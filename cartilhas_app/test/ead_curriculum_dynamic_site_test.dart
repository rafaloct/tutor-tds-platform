import 'dart:convert';

import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_curriculum_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const course = EadCourse(id: 1356, slug: 'saf', title: 'SAF');

http.Response snapshot({required int revision}) {
  final items = <Map<String, Object>>[
    {
      'id': 1425,
      'type': 'lp_lesson',
      'title': revision > 1
          ? 'Aula SAF atualizada no LearnPress'
          : 'Aula SAF antiga',
    },
    if (revision == 2)
      {'id': 901, 'type': 'lp_quiz', 'title': 'Quiz publicado no LMS'},
    if (revision == 3)
      {'id': 1703, 'type': 'lp_lesson', 'title': 'Nova videoaula no LMS'},
  ];
  if (revision == 3) items.removeAt(0);
  return http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'id': 1356,
        'sections': [
          {'id': 9001, 'title': 'Videoaulas do SAF', 'items': items},
        ],
      }),
    ),
    200,
  );
}

void main() {
  test(
    'atualiza videoaulas/quiz do curso sem mapa de seções compilado',
    () async {
      var revision = 1;
      final repo = EadCurriculumRepository(
        httpGet: (_) async => snapshot(revision: revision),
      );
      final v1 = await repo.fetch(course);
      expect(v1.videoCount, 1);
      expect(v1.lessonCount, 1);
      expect(v1.sections.first.lessons.first.title, 'Aula SAF antiga');
      revision = 2;
      final v2 = await repo.fetch(course);
      expect(v2.lessonCount, 2);
      expect(v2.videoCount, 1);
      expect(v2.sections.first.lessons.last.type, 'lp_quiz');
      expect(
        v2.sections.first.lessons.first.title,
        'Aula SAF atualizada no LearnPress',
      );
      revision = 3;
      final v3 = await repo.fetch(course);
      expect(v3.lessonCount, 1);
      expect(v3.sections.first.lessons.single.id, 1703);
      expect(v3.videoCount, 1);
    },
  );

  test('marcador editorial opcional identifica novo módulo de vídeo', () async {
    final repo = EadCurriculumRepository(
      httpGet: (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'id': 1356,
            'sections': [
              {
                'id': 20099,
                'title': 'Prática em grupo',
                'tds_content_type': 'video',
                'items': [
                  {
                    'id': 30211,
                    'type': 'lp_lesson',
                    'title': 'Experiência visual',
                  },
                ],
              },
            ],
          }),
        ),
        200,
      ),
    );
    final snapshot = await repo.fetch(course);
    expect(snapshot.videoCount, 1);
  });

  test(
    'módulo novo sem evidência de vídeo não recebe classificação inventada',
    () async {
      final repo = EadCurriculumRepository(
        httpGet: (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'id': 1356,
              'sections': [
                {
                  'id': 22341,
                  'title': 'Leitura e reflexão',
                  'items': [
                    {
                      'id': 31234,
                      'type': 'lp_lesson',
                      'title': 'Assista ao vídeo na prática',
                    },
                  ],
                },
              ],
            }),
          ),
          200,
        ),
      );
      expect((await repo.fetch(course)).videoCount, 0);
    },
  );
}
