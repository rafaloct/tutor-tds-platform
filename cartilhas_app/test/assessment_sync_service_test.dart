import 'dart:convert';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/study_ai/data/assessment_sync_service.dart';
import 'package:cartilhas_app/features/study_ai/models/assessment_sync_models.dart';
import 'package:cartilhas_app/features/study_ai/models/study_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TokenStore implements AuthTokenStore {
  _TokenStore({this.tokens});

  AuthTokens? tokens;

  @override
  Future<void> clear() async => tokens = null;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens tokens) async => this.tokens = tokens;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sucesso só marca sincronizado após resposta canônica', () async {
    late Map<String, dynamic> sent;
    final service = _service((request) async {
      expect(request.method, 'PUT');
      expect(request.headers['authorization'], 'Bearer access');
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'attempt_id': 'attempt-1', ...sent}),
        201,
      );
    });

    final result = await service.queueAndSync(_attempt());

    expect(result.status, AssessmentSyncStatus.synced);
    expect(result.confirmedRevision, 1);
    expect(sent['revision'], 1);
    expect(sent, isNot(contains('deck')));
    expect(sent, isNot(contains('weakTopics')));
    expect(sent, isNot(contains('difficulty')));
    expect(sent['score'], 0);
    expect(sent['assessment_content_id'], 'content:attempt-1');
  });

  test(
    'registra conteúdo antes da tentativa e aceita apenas score do servidor',
    () async {
      final paths = <String>[];
      late Map<String, dynamic> contentBody;
      late Map<String, dynamic> attemptBody;
      final service = _service((request) async {
        paths.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.startsWith('/assessment-contents/')) {
          contentBody = body;
          return http.Response(
            jsonEncode({
              'assessment_content_id': 'content:attempt-1',
              'course_id': body['course_id'],
              'topic': body['topic'],
              'mode': body['mode'],
              'title': body['title'],
              'duration_seconds': body['duration_seconds'],
              'questions': [
                for (final question in body['questions'] as List<dynamic>)
                  {
                    'question': question['question'],
                    'options': question['options'],
                    'topic': question['topic'],
                  },
              ],
              'answer_key': null,
              'created_at': '2026-09-20T15:25:00.000Z',
            }),
            201,
          );
        }
        attemptBody = body;
        return http.Response(
          jsonEncode({'attempt_id': 'attempt-1', ...body, 'score': 1}),
          201,
        );
      }, autoAcceptContent: false);

      final result = await service.queueAndSync(
        _attempt().copyWith(remainingSeconds: 0, score: 1, isCompleted: true),
      );

      expect(paths, [
        '/assessment-contents/content:attempt-1',
        '/assessment-attempts/attempt-1',
      ]);
      expect(contentBody['questions'], hasLength(1));
      expect(contentBody['questions'][0]['correct_index'], 2);
      expect(contentBody['questions'][0]['explanation'], 'Explicação');
      expect(attemptBody['assessment_content_id'], 'content:attempt-1');
      expect(attemptBody['score'], 0);
      expect(result.status, AssessmentSyncStatus.synced);
      expect(result.confirmedPayload?.score, 1);
    },
  );

  test('falha de rede preserva e retry repete exatamente a revisão', () async {
    final bodies = <String>[];
    var calls = 0;
    final service = _service((request) async {
      bodies.add(request.body);
      calls++;
      if (calls == 1) throw http.ClientException('offline');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'attempt_id': 'attempt-1', ...body}),
        200,
      );
    });
    final attempt = _attempt();

    final pending = await service.queueAndSync(attempt);
    final synced = await service.queueAndSync(attempt);

    expect(pending.status, AssessmentSyncStatus.pending);
    expect(synced.status, AssessmentSyncStatus.synced);
    expect(bodies, hasLength(2));
    expect(bodies[1], bodies[0]);
    expect((jsonDecode(bodies[1]) as Map<String, dynamic>)['revision'], 1);
  });

  test('API ausente mantém estado pendente e não chama rede', () async {
    var called = false;
    final service = _service((_) async {
      called = true;
      return http.Response('{}', 500);
    }, apiUrl: '');

    final result = await service.queueAndSync(_attempt());

    expect(result.status, AssessmentSyncStatus.pending);
    expect(result.lastError, 'api_unavailable');
    expect(called, isFalse);
  });

  test('sessão ausente mantém fila local sem chamar rede', () async {
    var called = false;
    final service = _service((_) async {
      called = true;
      return http.Response('{}', 500);
    }, signedIn: false);

    final result = await service.queueAndSync(_attempt());

    expect(result.status, AssessmentSyncStatus.pending);
    expect(result.lastError, 'session_required');
    expect(called, isFalse);
  });

  test('403 de matrícula preserva revisão para retry', () async {
    var calls = 0;
    final service = _service((_) async {
      calls++;
      return http.Response('{}', 403);
    });

    final result = await service.queueAndSync(_attempt());
    final changed = await service.queueAndSync(
      _attempt().copyWith(currentIndex: 1),
    );

    expect(result.status, AssessmentSyncStatus.pending);
    expect(result.lastError, 'active_enrollment_required');
    expect(result.pending.single.wasAttempted, isTrue);
    expect(changed.lastError, 'active_enrollment_required');
    expect(calls, 1, reason: 'autosave não deve criar loop de 403');

    await service.retry('attempt-1');
    expect(
      calls,
      2,
      reason: 'o vínculo pode ser revalidado sob ação explícita',
    );
  });

  test('409 consulta servidor e exige resolução explícita', () async {
    final requests = <http.Request>[];
    final remote = _payload(revision: 2, answers: const {'0': 1});
    final service = _service((request) async {
      requests.add(request);
      if (request.method == 'PUT') {
        return http.Response(
          jsonEncode({
            'detail': {
              'code': 'revision_conflict',
              'current_revision': 2,
              'expected_revision': 3,
            },
          }),
          409,
        );
      }
      return http.Response(
        jsonEncode({'attempt_id': 'attempt-1', ...remote}),
        200,
      );
    });

    final result = await service.queueAndSync(_attempt());

    expect(requests.map((item) => item.method), ['PUT', 'GET']);
    expect(result.status, AssessmentSyncStatus.conflict);
    expect(result.pending, hasLength(1));
    expect(result.remoteConflict?.payload.revision, 2);
    expect(result.remoteConflict?.payload.answers, {0: 1});
  });

  test('resolução explícita local parte da revisão remota mais um', () async {
    final revisions = <int>[];
    var firstPut = true;
    final remote = _payload(revision: 2, answers: const {'0': 1});
    final service = _service((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'attempt_id': 'attempt-1', ...remote}),
          200,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      revisions.add(body['revision'] as int);
      if (firstPut) {
        firstPut = false;
        return http.Response(
          jsonEncode({
            'detail': {'code': 'revision_conflict'},
          }),
          409,
        );
      }
      return http.Response(
        jsonEncode({'attempt_id': 'attempt-1', ...body}),
        200,
      );
    });
    final local = _attempt(answers: const {0: 0});
    await service.queueAndSync(local);

    final result = await service.resolveKeepingLocal(local);

    expect(revisions, [1, 3]);
    expect(result.status, AssessmentSyncStatus.synced);
    expect(result.confirmedRevision, 3);
  });

  test(
    'descobre tentativas incompletas por curso e modo sem inventar deck',
    () async {
      final service = _service((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/assessment-attempts');
        expect(request.url.queryParameters, {
          'course_id': 'course-1',
          'mode': 'exam',
          'completed': 'false',
          'limit': '50',
          'offset': '0',
        });
        return http.Response(
          jsonEncode({
            'attempts': [
              {
                'attempt_id': 'attempt-remote',
                ..._payload(revision: 3, answers: const {'0': 2}),
              },
            ],
            'total': 1,
            'limit': 50,
            'offset': 0,
          }),
          200,
        );
      });

      final attempts = await service.discoverIncomplete(
        courseId: 'course-1',
        mode: AssessmentMode.exam,
      );

      expect(attempts.single.attemptId, 'attempt-remote');
      expect(attempts.single.payload.revision, 3);
      expect(attempts.single.payload.answers, {0: 2});
    },
  );

  test('hidrata tentativa incompleta sem fabricar gabarito', () async {
    final remote = RemoteAssessmentAttempt(
      attemptId: 'attempt-remote',
      payload: AssessmentSyncPayload.fromJson({
        ..._payload(revision: 3, answers: const {'0': 2}),
        'assessment_content_id': 'content:remote',
      }),
    );
    final service = _service((request) async {
      expect(request.url.path, '/assessment-attempts/attempt-remote/content');
      return http.Response(
        jsonEncode({
          'assessment_content_id': 'content:remote',
          'course_id': 'course-1',
          'topic': 'Cooperativismo',
          'mode': 'exam',
          'title': 'Simulado remoto',
          'duration_seconds': 600,
          'questions': [
            {
              'question': 'Questão?',
              'options': ['A', 'B', 'C'],
              'topic': 'Cooperativismo',
            },
          ],
          'answer_key': null,
          'created_at': '2026-09-20T15:25:00.000Z',
        }),
        200,
      );
    });

    final hydrated = await service.hydrateRemoteAttempt(remote);

    expect(hydrated.id, 'attempt-remote');
    expect(hydrated.assessmentContentId, 'content:remote');
    expect(hydrated.answers, {0: 2});
    expect(hydrated.deck.hasAnswerKey, isFalse);
    expect(hydrated.deck.items.single.correctIndex, -1);
  });

  test(
    'hidrata conclusão com score e gabarito liberados pelo servidor',
    () async {
      final remote = RemoteAssessmentAttempt(
        attemptId: 'attempt-completed',
        payload: AssessmentSyncPayload.fromJson({
          ..._payload(revision: 4, answers: const {'0': 2}),
          'assessment_content_id': 'content:completed',
          'completed': true,
          'remaining_seconds': 0,
          'score': 1,
        }),
      );
      final service = _service((request) async {
        expect(
          request.url.path,
          '/assessment-attempts/attempt-completed/content',
        );
        return http.Response(
          jsonEncode({
            'assessment_content_id': 'content:completed',
            'course_id': 'course-1',
            'topic': 'Cooperativismo',
            'mode': 'exam',
            'title': 'Simulado remoto',
            'duration_seconds': 600,
            'questions': [
              {
                'question': 'Questão?',
                'options': ['A', 'B', 'C'],
                'topic': 'Cooperativismo',
              },
            ],
            'answer_key': [
              {'correct_index': 2, 'explanation': 'Explicação validada'},
            ],
            'created_at': '2026-09-20T15:25:00.000Z',
          }),
          200,
        );
      });

      final hydrated = await service.hydrateRemoteAttempt(remote);

      expect(hydrated.isCompleted, isTrue);
      expect(hydrated.score, 1);
      expect(hydrated.deck.hasAnswerKey, isTrue);
      expect(hydrated.deck.items.single.explanation, 'Explicação validada');
      expect(hydrated.weakTopics, isEmpty);
    },
  );

  test(
    'legado sem assessment_content_id é informado sem chamada insegura',
    () async {
      final service = _service((_) async => http.Response('{}', 500));
      final remote = RemoteAssessmentAttempt(
        attemptId: 'legacy',
        payload: AssessmentSyncPayload(
          courseId: 'course-1',
          topic: 'Cooperativismo',
          mode: AssessmentMode.quiz,
          revision: 1,
          answers: const {},
          marked: const {},
          currentIndex: 0,
          remainingSeconds: 0,
          completed: false,
          score: 0,
          updatedAt: DateTime.utc(2026, 9, 20),
        ),
      );

      await expectLater(
        service.hydrateRemoteAttempt(remote),
        throwsA(isA<AssessmentLegacyContentException>()),
      );
    },
  );
}

AssessmentSyncService _service(
  Future<http.Response> Function(http.Request request) handler, {
  String apiUrl = 'https://api.example',
  bool signedIn = true,
  bool autoAcceptContent = true,
}) {
  final store = _TokenStore(
    tokens: signedIn
        ? const AuthTokens(accessToken: 'access', refreshToken: 'refresh')
        : null,
  );
  final auth = AuthRepository(
    apiUrl: apiUrl.isEmpty ? 'https://auth.example' : apiUrl,
    client: MockClient((_) async => http.Response('{}', 500)),
    tokenStore: store,
  );
  return AssessmentSyncService(
    apiUrl: apiUrl,
    authRepository: auth,
    client: MockClient((request) {
      if (autoAcceptContent &&
          request.url.path.startsWith('/assessment-contents/')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return Future.value(
          http.Response(
            jsonEncode({
              'assessment_content_id': request.url.pathSegments.last,
              'course_id': body['course_id'],
              'topic': body['topic'],
              'mode': body['mode'],
              'title': body['title'],
              'duration_seconds': body['duration_seconds'],
              'questions': [
                for (final question in body['questions'] as List<dynamic>)
                  {
                    'question': question['question'],
                    'options': question['options'],
                    'topic': question['topic'],
                  },
              ],
              'answer_key': null,
              'created_at': '2026-09-20T15:25:00.000Z',
            }),
            201,
          ),
        );
      }
      return handler(request);
    }),
  );
}

AssessmentAttempt _attempt({Map<int, int> answers = const {0: 2}}) {
  final updatedAt = DateTime.utc(2026, 9, 20, 15, 30);
  return AssessmentAttempt(
    id: 'attempt-1',
    courseId: 'course-1',
    topic: 'Cooperativismo',
    mode: AssessmentMode.exam,
    difficulty: StudyDifficulty.intermediate,
    totalQuestions: 1,
    deck: AssessmentDeck(
      title: 'Simulado',
      durationMinutes: 10,
      items: [
        StudyQuestion(
          question: 'Questão?',
          options: const ['A', 'B', 'C'],
          correctIndex: 2,
          explanation: 'Explicação',
          topic: 'Cooperativismo',
        ),
      ],
    ),
    answers: answers,
    currentIndex: 0,
    remainingSeconds: 420,
    score: 0,
    weakTopics: const [],
    isCompleted: false,
    createdAt: updatedAt.subtract(const Duration(minutes: 5)),
    updatedAt: updatedAt,
  );
}

Map<String, dynamic> _payload({
  required int revision,
  required Map<String, int> answers,
}) => {
  'assessment_content_id': 'content:attempt-1',
  'course_id': 'course-1',
  'topic': 'Cooperativismo',
  'mode': 'exam',
  'revision': revision,
  'answers': answers,
  'marked': <int>[],
  'current_index': 0,
  'remaining_seconds': 420,
  'completed': false,
  'score': 0,
  'updated_at': '2026-09-20T15:30:00.000Z',
};
