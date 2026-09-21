import 'dart:convert';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FollowupAuth implements AuthRepository {
  String? owner = 'teacher';
  @override
  Future<String?> localUserId() async => owner;
  @override
  Future<http.Response> authorized(
    Future<http.Response> Function(String) operation,
  ) => operation('access');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('baseline and mentorship preserve class scope and API prefix', () async {
    final requests = <http.Request>[];
    final repo = ClassroomRepository(
      apiUrl: 'https://example.test/staging-api',
      authRepository: FollowupAuth(),
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer access');
        return http.Response('{}', 200);
      }),
    );
    addTearDown(repo.dispose);
    await repo.studentBaseline('class-a', 'student');
    await repo.saveStudentBaseline(
      classId: 'class-a',
      userId: 'student',
      source: 'baseline-tablet',
      recordId: 'tablet-123456',
      baselineDate: '2026-09-21',
      expectedRevision: 0,
      reason: ' Conferido pela equipe ',
      idempotencyKey: 'baseline-key',
    );
    await repo.mentorshipCases('class-a', 'student', offset: 50);
    await repo.openMentorship(
      classId: 'class-a',
      userId: 'student',
      mentorId: 'teacher',
      objective: 'Acompanhar estudo',
      nextAction: 'Conversar com aluno',
      reason: 'Solicitação da equipe',
      idempotencyKey: 'mentorship-key',
    );
    await repo.mentorshipCase('class-a', 'case-1');
    await repo.updateMentorship(
      classId: 'class-a',
      caseId: 'case-1',
      expectedRevision: 1,
      mentorId: 'teacher',
      objective: 'Acompanhar estudo',
      nextAction: 'Rever progresso',
      status: 'in_progress',
      reason: 'Início do atendimento',
      idempotencyKey: 'mentorship-update',
    );
    expect(requests.map((r) => r.method), [
      'GET',
      'PUT',
      'GET',
      'POST',
      'GET',
      'PATCH',
    ]);
    expect(
      requests.every(
        (r) => r.url.path.startsWith('/staging-api/classes/class-a/'),
      ),
      isTrue,
    );
    expect(jsonDecode(requests[1].body)['record_id'], 'tablet-123456');
    expect(jsonDecode(requests[1].body)['reason'], 'Conferido pela equipe');
    expect(requests[2].url.queryParameters, {
      'user_id': 'student',
      'limit': '50',
      'offset': '50',
    });
    expect(jsonDecode(requests.last.body)['expected_revision'], 1);
  });

  test('account change discards response and prevents later writes', () async {
    final auth = FollowupAuth();
    var calls = 0;
    final repo = ClassroomRepository(
      apiUrl: 'https://example.test',
      authRepository: auth,
      client: MockClient((request) async {
        calls++;
        auth.owner = 'other';
        return http.Response('{"baseline":{"record_id":"private"}}', 200);
      }),
    );
    addTearDown(repo.dispose);
    final denied = isA<ClassroomException>().having(
      (e) => e.statusCode,
      'status',
      401,
    );
    await expectLater(
      repo.studentBaseline('class-a', 'student'),
      throwsA(denied),
    );
    await expectLater(
      repo.openMentorship(
        classId: 'class-a',
        userId: 'student',
        mentorId: 'other',
        objective: 'Acompanhar estudo',
        nextAction: 'Conversar',
        reason: 'Pedido da equipe',
        idempotencyKey: 'cannot-write',
      ),
      throwsA(denied),
    );
    expect(calls, 1);
  });

  test('no local account sends no followup request', () async {
    final repo = ClassroomRepository(
      apiUrl: 'https://example.test',
      authRepository: FollowupAuth()..owner = null,
      client: MockClient((_) async => fail('Unexpected HTTP')),
    );
    addTearDown(repo.dispose);
    await expectLater(
      repo.studentBaseline('c', 's'),
      throwsA(
        isA<ClassroomException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
  });
}
