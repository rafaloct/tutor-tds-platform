import 'dart:async';
import 'dart:convert';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/learning_context/learning_context.dart';
import 'package:cartilhas_app/features/learning_context/learning_context_controller.dart';
import 'package:cartilhas_app/features/learning_context/learning_context_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> contextPayload({
  String cohort = 'class-1',
  String owner = 'student',
  String version = 'version-1',
}) => {
  'context': {
    'user_id': owner,
    'organization_id': 'org',
    'program_id': 'program',
    'cohort_id': cohort,
    'membership_id': 'membership-$cohort',
    'role': 'student',
    'course_id': 'course',
    'course_version_id': version,
    'enrollment_id': 'enrollment',
    'permissions': ['content.read', 'progress.read', 'activity.record'],
  },
  'progress': {
    'user_id': owner,
    'enrollment_id': 'enrollment',
    'progress_percent': 12.5,
    'validated_hours': 0.5,
  },
  'resolved_at': '2026-09-23T12:00:00Z',
  'contract_version': 'legacy-lineage-v1',
};

class ContextAuth extends AuthRepository {
  ContextAuth() : super(apiUrl: 'https://test.example');
  String? owner = 'student';
  @override
  Future<String?> localUserId() async => owner;
  @override
  Future<http.Response> authorized(
    Future<http.Response> Function(String) request,
  ) => request('test-token');
}

class DeferredContexts implements LearningContextRepository {
  final requests = <String, Completer<LearningContextSnapshot>>{};
  @override
  Future<LearningContextSnapshot> resolve(String cohortId) =>
      (requests[cohortId] = Completer()).future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'v2 persists both identities and preserves only the exact v1 reading scope',
    () {
      final v1 = LearningContextSnapshot.fromJson(contextPayload());
      final body = contextPayload();
      body['contract_version'] = 'cohort-enrollment-v2';
      body['context']['legacy_enrollment_id'] = 'enrollment';
      body['context']['enrollment_id'] = 'contextual-enrollment';
      body['progress']['context_enrollment_id'] = 'contextual-enrollment';
      final v2 = LearningContextSnapshot.fromJson(body);
      expect(v2.context.enrollmentId, 'contextual-enrollment');
      expect(
        v2.context.resumeKey('https://test.example'),
        v1.context.resumeKey('https://test.example'),
      );
      expect(
        LearningContextSnapshot.fromJson(v2.toCacheJson()).context.toJson(),
        v2.context.toJson(),
      );
      final other = contextPayload(cohort: 'parallel');
      expect(
        LearningContextSnapshot.fromJson(
          other,
        ).context.resumeKey('https://test.example'),
        isNot(v2.context.resumeKey('https://test.example')),
      );
      body['progress']['context_enrollment_id'] = 'other-enrollment';
      expect(
        () => LearningContextSnapshot.fromJson(body),
        throwsFormatException,
      );
      body['progress']['context_enrollment_id'] = 'contextual-enrollment';
      body['context'].remove('legacy_enrollment_id');
      expect(
        () => LearningContextSnapshot.fromJson(body),
        throwsFormatException,
      );
    },
  );

  test(
    'restart offline keeps exact context; cache expires and is environment isolated',
    () async {
      final auth = ContextAuth();
      addTearDown(auth.dispose);
      var offline = false;
      var now = DateTime.utc(2026, 9, 23, 13);
      RemoteLearningContextRepository repo({
        String url = 'https://test.example',
      }) {
        final value = RemoteLearningContextRepository(
          apiUrl: url,
          auth: auth,
          clock: () => now,
          client: MockClient((request) async {
            expect(request.headers['authorization'], 'Bearer test-token');
            if (offline) throw http.ClientException('offline');
            return http.Response(jsonEncode(contextPayload()), 200);
          }),
        );
        addTearDown(value.dispose);
        return value;
      }

      final first = await repo().resolve('class-1');
      expect(first.fromCache, isFalse);
      offline = true;
      final restored = await repo().resolve('class-1');
      expect(restored.fromCache, isTrue);
      expect(restored.context.toJson(), first.context.toJson());
      expect(restored.progressPercent, first.progressPercent);
      await expectLater(
        repo(url: 'https://production.example').resolve('class-1'),
        throwsA(isA<LearningContextException>()),
      );
      await expectLater(
        repo().resolve('class-2'),
        throwsA(isA<LearningContextException>()),
      );
      now = DateTime.utc(2026, 9, 30, 12);
      await expectLater(
        repo().resolve('class-1'),
        throwsA(isA<LearningContextException>()),
      );
    },
  );

  test('revocation deletes snapshot; offline never resurrects it', () async {
    final auth = ContextAuth();
    addTearDown(auth.dispose);
    var status = 200;
    final repo = RemoteLearningContextRepository(
      apiUrl: 'https://test.example',
      auth: auth,
      clock: () => DateTime.utc(2026, 9, 23, 13),
      client: MockClient((_) async {
        if (status == 0) throw http.ClientException('offline');
        return http.Response(jsonEncode(contextPayload()), status);
      }),
    );
    addTearDown(repo.dispose);
    await repo.resolve('class-1');
    status = 403;
    await expectLater(
      repo.resolve('class-1'),
      throwsA(
        isA<LearningContextException>().having(
          (e) => e.statusCode,
          'status',
          403,
        ),
      ),
    );
    status = 0;
    await expectLater(
      repo.resolve('class-1'),
      throwsA(isA<LearningContextException>()),
    );
  });

  test(
    'account change while request is in flight cannot cache another owner',
    () async {
      final auth = ContextAuth();
      addTearDown(auth.dispose);
      final repo = RemoteLearningContextRepository(
        apiUrl: 'https://test.example',
        auth: auth,
        client: MockClient((_) async {
          auth.owner = 'other';
          return http.Response(jsonEncode(contextPayload()), 200);
        }),
      );
      addTearDown(repo.dispose);
      await expectLater(
        repo.resolve('class-1'),
        throwsA(isA<LearningContextException>()),
      );
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );

  test('rejects mismatched identity and malformed permissions', () {
    final payload = contextPayload();
    (payload['progress'] as Map)['user_id'] = 'other';
    expect(
      () => LearningContextSnapshot.fromJson(payload),
      throwsFormatException,
    );
    final invalid = contextPayload();
    (invalid['context'] as Map)['permissions'] = ['content.read', 1];
    expect(
      () => LearningContextSnapshot.fromJson(invalid),
      throwsFormatException,
    );
  });

  test(
    'controller ignores late response from previously selected class and disposal',
    () async {
      final repo = DeferredContexts();
      final controller = LearningContextController(repo);
      final first = controller.load('class-1');
      final second = controller.load('class-2');
      repo.requests['class-2']!.complete(
        LearningContextSnapshot.fromJson(contextPayload(cohort: 'class-2')),
      );
      await second;
      repo.requests['class-1']!.complete(
        LearningContextSnapshot.fromJson(contextPayload()),
      );
      expect(await first, isNull);
      expect(controller.snapshot!.context.cohortId, 'class-2');
      final pending = controller.load('class-3');
      controller.dispose();
      repo.requests['class-3']!.complete(
        LearningContextSnapshot.fromJson(contextPayload(cohort: 'class-3')),
      );
      expect(await pending, isNull);
    },
  );
}
