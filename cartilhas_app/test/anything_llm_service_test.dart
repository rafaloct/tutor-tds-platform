import 'dart:convert';

import 'package:cartilhas_app/models/tutor_learning_context.dart';
import 'package:cartilhas_app/services/anything_llm_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('legacy Tutor request keeps message, mode and non-empty context', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{"text":"Resposta"}', 200);
    });
    final service = AnythingLLMService(
      gatewayUrl: 'https://gateway.example/',
      client: client,
    );
    addTearDown(client.close);

    expect(
      await service.getChatResponse(
        'Como começo?',
        mode: 'tutor',
        context: 'Agricultura',
      ),
      'Resposta',
    );
    expect(requestBody, {
      'message': 'Como começo?',
      'mode': 'tutor',
      'context': 'Agricultura',
    });
  });

  test('empty legacy context is omitted', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{"text":"Resposta"}', 200);
    });
    final service = AnythingLLMService(
      gatewayUrl: 'https://gateway.example',
      client: client,
    );
    addTearDown(client.close);

    await service.getChatResponse('Pergunta', context: '  ');

    expect(requestBody, {'message': 'Pergunta', 'mode': 'tutor'});
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
    await service.getChatResponse(
      'Pergunta A',
      context: 'reflection text is not transported',
      learningContext: contextA,
    );
    await service.getChatResponse(
      'Pergunta A na nova edição',
      learningContext: nextVersion,
    );
    await service.getChatResponse(
      'Pergunta B',
      context: 'reflection text is not transported',
      learningContext: contextB,
    );

    expect(requests, [
      {
        'message': 'Pergunta A',
        'mode': 'tutor',
        'learning_context': {
          'course_id': 'course-a',
          'course_version_id': 'version-1',
          'module_id': 'module-a1',
        },
      },
      {
        'message': 'Pergunta A na nova edição',
        'mode': 'tutor',
        'learning_context': {
          'course_id': 'course-a',
          'course_version_id': 'version-2',
          'module_id': 'module-a1',
        },
      },
      {
        'message': 'Pergunta B',
        'mode': 'tutor',
        'learning_context': {
          'course_id': 'course-b',
          'course_version_id': 'version-3',
          'module_id': 'module-b1',
        },
      },
    ]);
    expect(jsonEncode(requests), isNot(contains('reflection text')));
    expect(jsonEncode(requests), isNot(contains('userId')));
    expect(jsonEncode(requests), isNot(contains('enrollmentId')));
  });

  test('experience context uses stable typed IDs and known type values', () {
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
    expect(
      () => const TutorLearningContext(
        courseId: 'course-a',
        courseVersionId: 'version-2',
        moduleId: 'module-a1',
        experienceId: 'scenario-1',
      ).toJson(),
      throwsArgumentError,
    );
  });
}
