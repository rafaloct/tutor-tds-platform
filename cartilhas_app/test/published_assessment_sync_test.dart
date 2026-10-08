import 'dart:convert';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/study_ai/data/assessment_sync_queue.dart';
import 'package:cartilhas_app/features/study_ai/data/assessment_sync_service.dart';
import 'package:cartilhas_app/features/study_ai/models/assessment_sync_models.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'published_block usa PUT existente sem content PUT nem gabarito do cliente',
    () async {
      final requests = <http.Request>[];
      final service = _service((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'attempt_id': 'attempt:published:stable',
            ...body,
            'assessment_content_id': 'published:server-derived',
          }),
          201,
        );
      });

      final result = await service.queueAndSync(_attempt());

      expect(requests, hasLength(1));
      expect(
        requests.single.url.path,
        '/assessment-attempts/attempt:published:stable',
      );
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['origin'], 'published_block');
      expect(body['assessment_content_id'], isNull);
      expect(body, isNot(contains('answer_key')));
      expect(body, isNot(contains('questions')));
      expect(body, isNot(contains('isCorrect')));
      expect(body['class_id'], 'class-1');
      expect(body['enrollment_id'], 'context-enrollment-1');
      expect(body['legacy_enrollment_id'], 'legacy-enrollment-1');
      expect(body['course_version_id'], 'version-1');
      expect(body['section_version_id'], 'section-version-1');
      expect(body['block_version_id'], 'block-version-1');
      expect(result.status, AssessmentSyncStatus.synced);
      expect(
        result.confirmedPayload?.assessmentContentId,
        'published:server-derived',
      );
    },
  );

  test('404 do write contextual permanece local e bloqueia ativação', () async {
    final service = _service((_) async => http.Response('{}', 404));

    final result = await service.queueAndSync(_attempt());

    expect(result.status, AssessmentSyncStatus.pending);
    expect(result.lastError, 'dynamic_activity_unavailable');
    expect(result.pending, hasLength(1));
  });

  for (final response in <String, String>{
    'JSON malformado': '{',
    'shape contextual incompleto': jsonEncode({
      'attempt_id': 'attempt:published:stable',
      'origin': 'published_block',
      'revision': 1,
    }),
  }.entries) {
    test(
      '2xx com ${response.key} falha fechado como resposta inválida',
      () async {
        final service = _service(
          (_) async => http.Response(response.value, 200),
        );

        final result = await service.queueAndSync(_attempt());

        expect(result.status, AssessmentSyncStatus.pending);
        expect(result.lastError, 'invalid_server_response');
        expect(result.pending, hasLength(1));
        expect(result.pending.single.wasAttempted, isTrue);
      },
    );
  }

  test(
    '422 future_updated_at corrige somente horário e repete a mesma revisão',
    () async {
      final requests = <Map<String, dynamic>>[];
      const serverTime = '2026-10-07T10:30:00.000Z';
      final service = _service((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        if (requests.length == 1) {
          return http.Response(
            jsonEncode({
              'detail': {
                'code': 'future_updated_at',
                'server_time': serverTime,
                'max_future_seconds': 300,
              },
            }),
            422,
          );
        }
        return http.Response(
          jsonEncode({
            'attempt_id': 'attempt:published:stable',
            ...body,
            'assessment_content_id': 'published:server-derived',
          }),
          201,
        );
      });

      final result = await service.queueAndSync(_attempt());

      expect(requests, hasLength(2));
      final rejected = Map<String, dynamic>.from(requests.first)
        ..remove('updated_at');
      final retried = Map<String, dynamic>.from(requests.last)
        ..remove('updated_at');
      expect(retried, rejected);
      expect(requests.first['revision'], requests.last['revision']);
      expect(requests.first['updated_at'], isNot(serverTime));
      expect(requests.last['updated_at'], serverTime);
      expect(result.status, AssessmentSyncStatus.synced);
      expect(result.confirmedRevision, 1);
    },
  );

  test('outros 422 permanecem permanentes e não são repetidos', () async {
    var requests = 0;
    final service = _service((_) async {
      requests++;
      return http.Response(
        jsonEncode({
          'detail': {'code': 'published_block_identity_conflict'},
        }),
        422,
      );
    });

    final result = await service.queueAndSync(_attempt());

    expect(requests, 1);
    expect(result.status, AssessmentSyncStatus.pending);
    expect(result.lastError, 'server_422');
    expect(result.pending.single.payload.revision, 1);
  });

  test('future_updated_at repetido faz uma só correção automática', () async {
    var requests = 0;
    const serverTime = '2026-10-07T10:30:00.000Z';
    final service = _service((_) async {
      requests++;
      return http.Response(
        jsonEncode({
          'detail': {
            'code': 'future_updated_at',
            'server_time': serverTime,
            'max_future_seconds': 300,
          },
        }),
        422,
      );
    });

    final result = await service.queueAndSync(_attempt());

    expect(requests, 2);
    expect(result.status, AssessmentSyncStatus.pending);
    expect(result.lastError, 'server_422');
    expect(result.pending.single.payload.revision, 1);
    expect(result.pending.single.payload.updatedAt, DateTime.parse(serverTime));
  });

  test(
    'correção de rev2 respeita horário monotônico já aceito pelo servidor',
    () async {
      final requests = <Map<String, dynamic>>[];
      const serverTime = '2026-10-07T10:30:00.000Z';
      final service = _service((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        if (requests.length == 2) {
          return http.Response(
            jsonEncode({
              'detail': {
                'code': 'future_updated_at',
                'server_time': serverTime,
                'max_future_seconds': 300,
              },
            }),
            422,
          );
        }
        return http.Response(
          jsonEncode({
            'attempt_id': 'attempt:published:stable',
            ...body,
            'assessment_content_id': 'published:server-derived',
          }),
          requests.length == 1 ? 201 : 200,
        );
      });
      final first = _attempt().copyWith(
        updatedAt: DateTime.utc(2026, 10, 7, 10, 34),
      );
      await service.queueAndSync(first);

      final result = await service.queueAndSync(
        first.copyWith(
          reviewQuestionIndexes: const {0},
          updatedAt: DateTime.utc(2026, 10, 7, 10, 36),
        ),
      );

      expect(requests, hasLength(3));
      expect(requests.map((body) => body['revision']), [1, 2, 2]);
      expect(requests.map((body) => body['updated_at']), [
        '2026-10-07T10:34:00.000Z',
        '2026-10-07T10:36:00.000Z',
        '2026-10-07T10:34:00.000Z',
      ]);
      expect(result.status, AssessmentSyncStatus.synced);
      expect(result.confirmedRevision, 2);
      expect(result.confirmedPayload?.marked, {0});
    },
  );

  test(
    'server_time inconsistente não é usado para reescrever a fila',
    () async {
      var requests = 0;
      final service = _service((_) async {
        requests++;
        return http.Response(
          jsonEncode({
            'detail': {
              'code': 'future_updated_at',
              'server_time': '2024-01-01T00:00:00.000Z',
              'max_future_seconds': 300,
            },
          }),
          422,
        );
      });

      final result = await service.queueAndSync(_attempt());

      expect(requests, 1);
      expect(result.lastError, 'server_422');
      expect(
        result.pending.single.payload.updatedAt,
        DateTime.utc(2026, 10, 7, 12),
      );
    },
  );

  test('retomada usa apenas as rotas contextuais da turma', () async {
    final paths = <String>[];
    final remoteJson = {
      'attempt_id': 'attempt:published:stable',
      ..._payloadJson(),
      'assessment_content_id': 'published:server-derived',
    };
    final service = _service((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/content')) {
        return http.Response(
          jsonEncode({
            'assessment_content_id': 'published:server-derived',
            'course_id': 'course-1',
            'topic': 'Módulo',
            'mode': 'quiz',
            'title': 'Bloco publicado',
            'duration_seconds': 0,
            'questions': [
              {
                'question': 'Pergunta?',
                'options': ['A', 'B', 'C'],
                'topic': 'Módulo',
              },
            ],
            'answer_key': null,
            'created_at': '2026-10-07T12:00:00Z',
          }),
          200,
        );
      }
      return http.Response(jsonEncode(remoteJson), 200);
    });

    final discovered = await service.findPublishedAttempt(
      _context(),
      'attempt:published:stable',
    );
    final hydrated = await service.hydrateRemoteAttempt(discovered!);

    expect(paths, [
      '/classes/class-1/assessment-attempts/attempt%3Apublished%3Astable',
      '/classes/class-1/assessment-attempts/attempt%3Apublished%3Astable/content',
    ]);
    expect(hydrated.id, 'attempt:published:stable');
    expect(hydrated.origin, AssessmentOrigin.publishedBlock);
    expect(hydrated.publishedContext?.ownerId, 'student-1');
    expect(hydrated.publishedContext?.apiUrl, 'https://api.example');
    expect(hydrated.deck.hasAnswerKey, isFalse);
  });

  test(
    'gabarito server-side preserva múltiplas corretas e questão sem nota',
    () {
      final graded = RemoteAssessmentContent.fromJson({
        'assessment_content_id': 'published:graded',
        'course_id': 'course-1',
        'topic': 'Módulo',
        'mode': 'quiz',
        'title': 'Quiz',
        'duration_seconds': 0,
        'questions': [
          {
            'question': 'Pergunta?',
            'options': ['A', 'B', 'C'],
            'topic': 'Módulo',
          },
        ],
        'answer_key': [
          {
            'correct_indices': [0, 1],
            'explanation': 'As duas são aceitas.',
            'graded': true,
          },
        ],
        'created_at': '2026-10-07T12:00:00Z',
      });
      final ungraded = RemoteAssessmentContent.fromJson({
        'assessment_content_id': 'published:question',
        'course_id': 'course-1',
        'topic': 'Módulo',
        'mode': 'quiz',
        'title': 'Pergunta',
        'duration_seconds': 0,
        'questions': [
          {
            'question': 'Compartilhe sua resposta',
            'options': ['A', 'B'],
            'topic': 'Módulo',
          },
        ],
        'answer_key': [
          {
            'correct_indices': <int>[],
            'explanation': 'Resposta registrada sem nota.',
            'graded': false,
          },
        ],
        'created_at': '2026-10-07T12:00:00Z',
      });

      expect(graded.questions.single.correctIndexes, {0, 1});
      expect(graded.questions.single.graded, isTrue);
      expect(ungraded.questions.single.correctIndexes, isEmpty);
      expect(ungraded.questions.single.graded, isFalse);
      expect(ungraded.hasAnswerKey, isTrue);
    },
  );

  test(
    'consulta exata também retoma conclusão feita em outro aparelho',
    () async {
      final service = _service(
        (_) async => http.Response(
          jsonEncode({
            'attempt_id': 'attempt:published:stable',
            ..._payloadJson(completed: true),
          }),
          200,
        ),
      );

      final remote = await service.findPublishedAttempt(
        _context(),
        'attempt:published:stable',
      );

      expect(remote, isNotNull);
      expect(remote?.payload.completed, isTrue);
    },
  );

  test(
    'remote idêntico recompõe escopo da fila antes da próxima mutação',
    () async {
      final service = _service((_) async => http.Response('{}', 500));
      final local = _attempt();
      final remote = RemoteAssessmentAttempt.fromJson({
        'attempt_id': local.id,
        ..._payloadJson(),
      });

      final accepted = await service.registerDiscovered(local, remote);
      expect(accepted.status, AssessmentSyncStatus.synced);
      expect(accepted.localContext?.sameAs(local.publishedContext), isTrue);

      final queued = await service.queueAttempt(
        local.copyWith(
          answers: const {0: 0},
          updatedAt: DateTime.utc(2026, 10, 7, 13),
        ),
      );
      expect(queued.status, AssessmentSyncStatus.pending);
      expect(queued.localContext?.sameAs(local.publishedContext), isTrue);
    },
  );

  test(
    'flush envia payload substituído antes de marcar a revisão tentada',
    () async {
      final requests = <Map<String, dynamic>>[];
      final queue = _InterleavingQueue();
      late AssessmentSyncService service;
      service = _service((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        return http.Response(
          jsonEncode({
            'attempt_id': 'attempt:published:stable',
            ...body,
            'assessment_content_id': 'published:server-derived',
          }),
          201,
        );
      }, queue: queue);
      final updated = _attempt().copyWith(
        answers: const {0: 0},
        updatedAt: DateTime.utc(2026, 10, 7, 13),
      );
      queue.beforeFirstMark = () async {
        await service.queueAttempt(updated);
      };

      final result = await service.queueAndSync(_attempt());

      expect(requests, hasLength(1));
      expect((requests.single['answers'] as Map<String, dynamic>)['0'], 0);
      expect(result.status, AssessmentSyncStatus.synced);
      expect(result.confirmedPayload?.answers, {0: 0});
    },
  );
}

AssessmentSyncService _service(
  Future<http.Response> Function(http.Request request) handler, {
  AssessmentSyncQueue queue = const AssessmentSyncQueue(),
}) => AssessmentSyncService(
  apiUrl: 'https://api.example/',
  authRepository: _ContextAuth(),
  queue: queue,
  client: MockClient(handler),
  clock: () => DateTime.utc(2026, 10, 7, 10, 30),
);

class _InterleavingQueue extends AssessmentSyncQueue {
  Future<void> Function()? beforeFirstMark;
  bool _interleaved = false;

  @override
  Future<AssessmentSyncRecord> markAttempted(
    String attemptId,
    int revision,
  ) async {
    if (!_interleaved) {
      _interleaved = true;
      await beforeFirstMark?.call();
    }
    return super.markAttempted(attemptId, revision);
  }
}

class _ContextAuth extends AuthRepository {
  _ContextAuth() : super(apiUrl: 'https://api.example');

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<String?> localUserId() async => 'student-1';

  @override
  Future<http.Response> authorized(
    Future<http.Response> Function(String accessToken) request,
  ) => request('access');
}

PublishedAssessmentContext _context() => PublishedAssessmentContext(
  ownerId: 'student-1',
  apiUrl: 'https://api.example/',
  lineage: const PublishedAssessmentLineage(
    organizationId: 'org-1',
    programId: 'program-1',
    classId: 'class-1',
    membershipId: 'membership-1',
    enrollmentId: 'context-enrollment-1',
    legacyEnrollmentId: 'legacy-enrollment-1',
    courseId: 'course-1',
    courseVersionId: 'version-1',
    sectionId: 'section-1',
    sectionVersionId: 'section-version-1',
    blockId: 'block-1',
    blockVersionId: 'block-version-1',
  ),
);

AssessmentAttempt _attempt() => AssessmentAttempt(
  id: 'attempt:published:stable',
  origin: AssessmentOrigin.publishedBlock,
  publishedContext: _context(),
  courseId: 'course-1',
  topic: 'Módulo',
  mode: AssessmentMode.quiz,
  difficulty: StudyDifficulty.intermediate,
  totalQuestions: 1,
  deck: AssessmentDeck(
    title: 'Bloco publicado',
    durationMinutes: 0,
    items: [
      StudyQuestion(
        question: 'Pergunta?',
        options: const ['A', 'B', 'C'],
        correctIndex: -1,
        correctIndexes: const {},
        graded: false,
        explanation: '',
        topic: 'Módulo',
      ),
    ],
  ),
  answers: const {0: 1},
  currentIndex: 0,
  remainingSeconds: 0,
  score: 0,
  weakTopics: const [],
  isCompleted: false,
  createdAt: DateTime.utc(2026, 10, 7, 12),
  updatedAt: DateTime.utc(2026, 10, 7, 12),
);

Map<String, dynamic> _payloadJson({bool completed = false}) => {
  'origin': 'published_block',
  'course_id': 'course-1',
  'assessment_content_id': 'published:server-derived',
  'topic': 'Módulo',
  'mode': 'quiz',
  ..._context().lineage.toJson(),
  'revision': 1,
  'answers': {'0': 1},
  'marked': <int>[],
  'current_index': 0,
  'remaining_seconds': 0,
  'completed': completed,
  'score': 0,
  'updated_at': '2026-10-07T12:00:00Z',
};
