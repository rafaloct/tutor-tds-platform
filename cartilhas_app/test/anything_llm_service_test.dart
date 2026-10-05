import 'dart:convert';

import 'package:cartilhas_app/models/tutor_learning_context.dart';
import 'package:cartilhas_app/services/anything_llm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('legacy request preserves the focused chat contract', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'text': 'Resposta TDS'}), 200);
    });
    final service = AnythingLLMService(
      gatewayUrl: 'https://gateway.example/',
      client: client,
    );
    addTearDown(client.close);

    expect(
      await service.getChatResponse(
        'Como funciona?',
        mode: 'adaptive',
        context: 'Cooperativismo',
      ),
      'Resposta TDS',
    );
    expect(captured.url.toString(), 'https://gateway.example/v1/chat');
    expect(captured.headers['content-type'], 'application/json');
    expect(jsonDecode(captured.body), {
      'message': 'Como funciona?',
      'mode': 'adaptive',
      'context': 'Cooperativismo',
    });
  });

  test('empty legacy context is omitted and empty response gets fallback', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{"text":""}', 200);
    });
    final service = AnythingLLMService(
      gatewayUrl: 'https://gateway.example',
      client: client,
    );
    addTearDown(client.close);

    expect(
      await service.getChatResponse('Pergunta', context: '  '),
      'O Tutor não encontrou uma resposta. Tente reformular a pergunta.',
    );
    expect(requestBody, {'message': 'Pergunta', 'mode': 'tutor'});
  });

  test('gateway failures use the availability fallback', () async {
    final client = MockClient(
      (_) async => http.Response('{"error":"rate_limited"}', 429),
    );
    final service = AnythingLLMService(
      gatewayUrl: 'https://gateway.example',
      client: client,
    );
    addTearDown(client.close);

    expect(
      await service.getChatResponse('Pergunta'),
      contains('temporariamente indisponível'),
    );
  });

  test('invalid configured gateway URL uses the availability fallback', () async {
    final client = MockClient((_) async => throw StateError('must not send'));
    final service = AnythingLLMService(
      gatewayUrl: 'https://[invalid',
      client: client,
    );
    addTearDown(client.close);

    expect(
      await service.getChatResponse('Pergunta'),
      contains('temporariamente indisponível'),
    );
  });

  test('context switches send only the new structured academic scope', () async {
    final requests = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('{"text":"Resposta"}', 200);
    });
    final service = AnythingLLMService(
      gatewayUrl: 'https://gateway.example',
      client: client,
    );
    addTearDown(client.close);

    const contextA = TutorLearningContext(
      courseId: 'course-a',
      courseVersionId: 'version-1',
      moduleId: 'module-a1',
    );
    const contextB = TutorLearningContext(
      courseId: 'course-b',
      courseVersionId: 'version-3',
      moduleId: 'module-b1',
    );
    const nextVersion = TutorLearningContext(
      courseId: 'course-a',
      courseVersionId: 'version-2',
      moduleId: 'module-a1',
    );
    await service.getChatResponse('Pergunta A', learningContext: contextA);
    await service.getChatResponse(
      'Pergunta A na nova edição',
      learningContext: nextVersion,
    );
    await service.getChatResponse('Pergunta B', learningContext: contextB);

    expect(
      requests.map((request) => request['learning_context']),
      [
        {
          'course_id': 'course-a',
          'course_version_id': 'version-1',
          'module_id': 'module-a1',
        },
        {
          'course_id': 'course-a',
          'course_version_id': 'version-2',
          'module_id': 'module-a1',
        },
        {
          'course_id': 'course-b',
          'course_version_id': 'version-3',
          'module_id': 'module-b1',
        },
      ],
    );
    expect(jsonEncode(requests), isNot(contains('userId')));
    expect(jsonEncode(requests), isNot(contains('enrollmentId')));
  });

  test('experience is serialized only when present and requires module', () {
    const context = TutorLearningContext(
      courseId: 'course-a',
      courseVersionId: 'version-2',
      moduleId: 'module-a1',
      experienceId: 'scenario-1',
      experienceType: TutorExperienceType.scenario,
    );

    expect(context.toJson(), {
      'course_id': 'course-a',
      'course_version_id': 'version-2',
      'module_id': 'module-a1',
      'experience_id': 'scenario-1',
      'experience_type': 'scenario',
    });
    expect(
      () => const TutorLearningContext(
        courseId: 'course-a',
        courseVersionId: 'version-2',
        experienceId: 'scenario-1',
        experienceType: TutorExperienceType.scenario,
      ).toJson(),
      throwsArgumentError,
    );
  });
}
