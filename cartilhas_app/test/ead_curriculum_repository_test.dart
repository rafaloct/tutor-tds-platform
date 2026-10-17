import 'dart:convert';
import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_curriculum_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const course = EadCourse(id: 1356, slug: 'saf', title: 'SAF');

Map<String, Object?> payload() => {
  'id': 1356,
  'sections': [
    {
      'id': 72,
      'title': 'O que é SAF?',
      'items': [
        {'id': 1357, 'title': 'O que é SAF?', 'type': 'lp_lesson'},
      ],
    },
    {
      'id': 80,
      'title': 'Assista em vídeo',
      'items': [
        {
          'id': 1425,
          'title': 'Aula 01 - Sistemas Agroflorestais',
          'type': 'lp_lesson',
        },
        {'id': 1426, 'title': 'Aula 02 - Benefícios', 'type': 'lp_lesson'},
      ],
    },
  ],
};

void main() {
  test(
    'preserva a ordem pública de módulos e videoaulas sem trazer provas',
    () async {
      Uri? requested;
      final repo = EadCurriculumRepository(
        httpGet: (uri) async {
          requested = uri;
          return http.Response.bytes(
            utf8.encode(jsonEncode(payload())),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      );
      final result = await repo.fetch(course);
      expect(requested!.host, 'ead.ipexdesenvolvimento.cloud');
      expect(requested!.path, '/wp-json/learnpress/v1/courses/1356');
      expect(result.sections.map((s) => s.id), [72, 80]);
      expect(result.lessonCount, 3);
      expect(result.videoCount, 2);
      expect(result.sections.first.lessons.first.isVideoCandidate, false);
      expect(result.sections.last.lessons.first.id, 1425);
    },
  );

  test('módulos IA da grade LearnPress mantêm indicação de vídeo', () async {
    final ia = const EadCourse(
      id: 614,
      slug: 'inteligencia-artificial-e-inclusao-digital',
      title: 'IA',
    );
    final repo = EadCurriculumRepository(
      httpGet: (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'id': 614,
            'sections': [
              {
                'id': 28,
                'title': 'Módulo 1 - Fundamentos',
                'items': [
                  {'id': 1295, 'title': 'Aula IA', 'type': 'lp_lesson'},
                ],
              },
              {
                'id': 67,
                'title': 'Material de referência - Cartilha',
                'items': [
                  {'id': 1351, 'title': 'O que é IA?', 'type': 'lp_lesson'},
                ],
              },
            ],
          }),
        ),
        200,
      ),
    );
    final result = await repo.fetch(ia);
    expect(result.videoCount, 1);
    expect(result.sections.last.lessons.first.isVideoCandidate, false);
  });

  test('falha fechado para curso inesperado e lição duplicada', () async {
    final invalidCourse = EadCurriculumRepository(
      httpGet: (_) async =>
          http.Response(jsonEncode({'id': 1111, 'sections': []}), 200),
    );
    expect(invalidCourse.fetch(course), throwsA(isA<EadCurriculumException>()));
    final duplicate = payload();
    final sections = duplicate['sections'] as List;
    ((sections.last as Map)['items'] as List).add({
      'id': 1425,
      'title': 'duplicada',
      'type': 'lp_lesson',
    });
    final repo = EadCurriculumRepository(
      httpGet: (_) async => http.Response(jsonEncode(duplicate), 200),
    );
    expect(repo.fetch(course), throwsA(isA<EadCurriculumException>()));
  });

  test('offline, 401 e JSON quebrado não simulam currículo', () async {
    final offline = EadCurriculumRepository(
      httpGet: (_) async => throw const FormatException('offline'),
    );
    expect(offline.fetch(course), throwsA(isA<EadCurriculumException>()));
    final protected = EadCurriculumRepository(
      httpGet: (_) async => http.Response('Unauthorized', 401),
    );
    expect(protected.fetch(course), throwsA(isA<EadCurriculumException>()));
  });

  test('quiz público futuro apenas identificado, não transfere nota', () async {
    final p = payload();
    final sections = p['sections'] as List;
    ((sections.first as Map)['items'] as List).add({
      'id': 1999,
      'title': 'Quiz de revisão',
      'type': 'lp_quiz',
    });
    final repo = EadCurriculumRepository(
      httpGet: (_) async => http.Response.bytes(utf8.encode(jsonEncode(p)), 200),
    );
    final result = await repo.fetch(course);
    expect(result.sections.first.lessons.last.type, 'lp_quiz');
    expect(result.sections.first.lessons.last.isVideoCandidate, false);
  });
}
