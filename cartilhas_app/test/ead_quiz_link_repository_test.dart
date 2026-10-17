import 'dart:convert';

import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_quiz_link_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_curriculum_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('obtém endereço público de quiz publicado, sem gabarito', () async {
    Uri? request;
    final repo = EadQuizLinkRepository(
      httpGet: (uri) async {
        request = uri;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'id': 640,
              'status': 'publish',
              'link':
                  'https://ead.ipexdesenvolvimento.cloud/quizzes/quiz-de-revisao/',
            }),
          ),
          200,
        );
      },
    );
    final uri = await repo.publishedQuizUri(640);
    expect(
      uri.toString(),
      'https://ead.ipexdesenvolvimento.cloud/quizzes/quiz-de-revisao/',
    );
    expect(request!.path, '/wp-json/wp/v2/lp_quiz/640');
    expect(request!.queryParameters['_fields'], 'id,status,link');
    expect(request!.queryParameters, isNot(contains('questions')));
    expect(request!.queryParameters, isNot(contains('answer_key')));
  });

  test('quiz oculto, não publicado ou removido não pode abrir', () async {
    for (final status in ['draft', 'pending', 'private']) {
      final repo = EadQuizLinkRepository(
        httpGet: (_) async => http.Response(
          jsonEncode({
            'id': 640,
            'status': status,
            'link': 'https://ead.ipexdesenvolvimento.cloud/quizzes/a/',
          }),
          200,
        ),
      );
      await expectLater(
        repo.publishedQuizUri(640),
        throwsA(isA<EadCurriculumException>()),
      );
    }
    final deleted = EadQuizLinkRepository(
      httpGet: (_) async => http.Response('Not Found', 404),
    );
    await expectLater(
      deleted.publishedQuizUri(640),
      throwsA(isA<EadCurriculumException>()),
    );
  });

  test('somente link HTTPS canônico LearnPress é aceito', () async {
    final bad = [
      'https://evil.example/quizzes/a/',
      'http://ead.ipexdesenvolvimento.cloud/quizzes/a/',
      'https://ead.ipexdesenvolvimento.cloud.evil.example/quizzes/a/',
      'https://ead.ipexdesenvolvimento.cloud/admin/',
      'https://ead.ipexdesenvolvimento.cloud/quizzes/a/?answers=1',
      'https://ead.ipexdesenvolvimento.cloud/quizzes/a/#answers',
      'https://login:pwd@ead.ipexdesenvolvimento.cloud/quizzes/a/',
    ];
    for (final link in bad) {
      final repo = EadQuizLinkRepository(
        httpGet: (_) async => http.Response(
          jsonEncode({'id': 640, 'status': 'publish', 'link': link}),
          200,
        ),
      );
      await expectLater(
        repo.publishedQuizUri(640),
        throwsA(isA<EadCurriculumException>()),
      );
    }
  });

  test('IDs divergentes, corpo malformado e falha de rede bloqueiam', () async {
    final wrong = EadQuizLinkRepository(
      httpGet: (_) async => http.Response(
        jsonEncode({
          'id': 641,
          'status': 'publish',
          'link': 'https://ead.ipexdesenvolvimento.cloud/quizzes/a/',
        }),
        200,
      ),
    );
    await expectLater(
      wrong.publishedQuizUri(640),
      throwsA(isA<EadCurriculumException>()),
    );
    final offline = EadQuizLinkRepository(
      httpGet: (_) async => throw Exception('offline'),
    );
    await expectLater(
      offline.publishedQuizUri(640),
      throwsA(isA<EadCurriculumException>()),
    );
  });
}
