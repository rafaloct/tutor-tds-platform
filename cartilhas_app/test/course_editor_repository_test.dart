import 'dart:convert';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/course_editor/data/course_editor_repository.dart';
import 'package:cartilhas_app/features/course_editor/models/course_editor_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Store implements AuthTokenStore {
  AuthTokens? tokens = const AuthTokens(
    accessToken: 'access',
    refreshToken: 'refresh',
  );
  @override
  Future<AuthTokens?> read() async => tokens;
  @override
  Future<void> write(AuthTokens value) async => tokens = value;
  @override
  Future<void> clear() async => tokens = null;
}

Map<String, dynamic> courseJson() => {
  'course_id': 'horta',
  'program_id': 'program-1',
  'version_id': 'version-1',
  'revision': 4,
  'version_number': 1,
  'status': 'draft',
  'title': 'Horta',
  'author': 'Ana',
  'can_edit': true,
  'can_submit': true,
  'can_publish': false,
  'sections': [
    {
      'id': 'module-1',
      'version_id': 'module-version',
      'title': 'Solo',
      'extra': 'preserve',
      'messages': [
        {
          'id': 'message-1',
          'version_id': 'message-version',
          'type': 'quiz',
          'content': 'Qual?',
          'explanation': 'Explicação',
          'options': [
            {
              'label': 'Sim',
              'value': 'stable-value',
              'isCorrect': true,
              'custom': 42,
            },
            {'label': 'Não', 'value': 'no', 'isCorrect': false},
          ],
        },
      ],
    },
  ],
};
void main() {
  for (final type in ['user', 'question', 'quiz']) {
    test(
      'publish rejects $type without options before making a request',
      () async {
        final json = courseJson();
        final message =
            ((json['sections'] as List).single['messages'] as List).single
                as Map<String, dynamic>;
        message['type'] = type;
        message.remove('options');
        var requests = 0;
        final repository = CourseEditorRepository(
          apiUrl: 'https://example.test',
          authRepository: AuthRepository(
            apiUrl: 'https://example.test',
            tokenStore: _Store(),
          ),
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
        );
        await expectLater(
          repository.transition(EditableCourse.fromJson(json), 'publish'),
          throwsA(
            isA<CourseEditorException>().having(
              (e) => e.message,
              'reason',
              contains('alternativa'),
            ),
          ),
        );
        expect(requests, 0);
        repository.dispose();
      },
    );
  }
  test('release rejects empty modules and unknown reader types', () {
    final json = courseJson();
    (json['sections'] as List).single['messages'] = <dynamic>[];
    expect(
      EditableCourse.fromJson(json).releaseValidationError,
      contains('uma mensagem'),
    );
    (json['sections'] as List).single['messages'] = [
      {'type': 'unsupported', 'content': 'Texto'},
    ];
    expect(
      EditableCourse.fromJson(json).releaseValidationError,
      contains('compatível'),
    );
  });
  test(
    'capabilities default to denied; published content remains read only',
    () {
      expect(
        EditorProgram.fromJson({
          'id': 'p',
          'name': 'P',
          'role': 'admin',
        }).canCreate,
        isFalse,
      );
      expect(
        EditableCourse.fromJson({
          ...courseJson(),
          'status': 'published',
        }).canEdit,
        isFalse,
      );
    },
  );
  test(
    'save preserves IDs and unknown nested metadata and sends revision',
    () async {
      final source = courseJson();
      final course = EditableCourse.fromJson(source);
      course.data['title'] = 'Novo título';
      final repository = CourseEditorRepository(
        apiUrl: 'https://example.test/',
        authRepository: AuthRepository(
          apiUrl: 'https://example.test',
          tokenStore: _Store(),
        ),
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/courses/horta');
          expect(request.headers['authorization'], 'Bearer access');
          final json = jsonDecode(request.body) as Map;
          expect(json['version_id'], 'version-1');
          expect(json['expected_revision'], 4);
          expect(json['sections'], source['sections']);
          expect(json.containsKey('can_publish'), isFalse);
          return http.Response(
            jsonEncode({...course.data, 'revision': 5}),
            200,
          );
        }),
      );
      expect((await repository.save(course)).revision, 5);
      expect(source['title'], 'Horta');
      repository.dispose();
    },
  );
  test(
    'context, scoped list and version reads use encoded parameters',
    () async {
      final repository = CourseEditorRepository(
        apiUrl: 'https://example.test',
        authRepository: AuthRepository(
          apiUrl: 'https://example.test',
          tokenStore: _Store(),
        ),
        client: MockClient((request) async {
          if (request.url.path == '/editor/context') {
            return http.Response(
              jsonEncode({
                'programs': [
                  {'id': 'p & 1', 'name': 'P', 'can_create': true},
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/editor/courses') {
            expect(request.url.queryParameters['program_id'], 'p & 1');
            return http.Response(
              jsonEncode({
                'courses': [courseJson()],
              }),
              200,
            );
          }
          expect(request.url.toString(), contains('course%2Fid'));
          expect(request.url.queryParameters['version_id'], 'v & 1');
          return http.Response(jsonEncode(courseJson()), 200);
        }),
      );
      expect((await repository.programs()).single.canCreate, isTrue);
      expect((await repository.courses('p & 1')).single.courseId, 'horta');
      await repository.course('course/id', versionId: 'v & 1');
      repository.dispose();
    },
  );
  test(
    'transitions and fork use the exact version without overwriting snapshot',
    () async {
      final requests = <http.Request>[];
      final repository = CourseEditorRepository(
        apiUrl: 'https://example.test',
        authRepository: AuthRepository(
          apiUrl: 'https://example.test',
          tokenStore: _Store(),
        ),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(courseJson()), 200);
        }),
      );
      final course = EditableCourse.fromJson(courseJson());
      for (final action in ['submit', 'publish', 'archive']) {
        await repository.transition(course, action);
        expect(requests.last.url.path, '/courses/horta/$action');
        expect(jsonDecode(requests.last.body), {
          'version_id': 'version-1',
          'expected_revision': 4,
        });
      }
      await repository.fork(course);
      expect(jsonDecode(requests.last.body), {
        'source_version_id': 'version-1',
      });
      repository.dispose();
    },
  );
  for (final status in [403, 409, 500]) {
    test('status $status produces safe error and conflict marker', () async {
      final repository = CourseEditorRepository(
        apiUrl: 'https://example.test',
        authRepository: AuthRepository(
          apiUrl: 'https://example.test',
          tokenStore: _Store(),
        ),
        client: MockClient(
          (_) async =>
              http.Response('{"detail":"secret internal trace"}', status),
        ),
      );
      await expectLater(
        repository.save(EditableCourse.fromJson(courseJson())),
        throwsA(
          isA<CourseEditorException>()
              .having((e) => e.conflict, 'conflict', status == 409)
              .having(
                (e) => e.message,
                'safe message',
                isNot(contains('secret')),
              ),
        ),
      );
      repository.dispose();
    });
  }
}
