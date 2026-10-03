import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/operations/operations_models.dart';
import 'package:cartilhas_app/features/operations/operations_repository.dart';
import 'fake_operations_gateway.dart';

class TestAuth extends AuthRepository {
  TestAuth() : super(apiUrl: 'https://synthetic.invalid');
  int generation = 0;
  @override
  int get sessionGeneration => generation;
  @override
  Future<String?> localUserId() async => 'operator';
  @override
  Future<http.Response> authorized(
    Future<http.Response> Function(String) request,
  ) => request('synthetic-token');
}

void main() {
  test(
    'HTTP lookup proof travels in inspect and enrollment bodies, never URL',
    () async {
      final auth = TestAuth();
      final bodies = <Map<String, dynamic>>[];
      final repository = OperationsRepository(
        apiUrl: 'https://synthetic.invalid',
        auth: auth,
        owner: 'operator',
        generation: 0,
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          expect(request.url.query, isEmpty);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          bodies.add(body);
          if (request.url.path.endsWith('/search')) {
            return http.Response(
              jsonEncode({
                'people': [
                  {
                    'id': 'person',
                    'name': 'Synthetic',
                    'identity_proof': 'signed-proof',
                  },
                ],
              }),
              200,
            );
          }
          expect(body['identity_proof'], 'signed-proof');
          return http.Response(
            jsonEncode({
              'person': {'id': 'person', 'name': 'Synthetic'},
              'scope': {
                'institution_id': scopeA.institutionId,
                'program_id': scopeA.programId,
                'course_id': scopeA.courseId,
                'class_id': scopeA.classId,
                'version_id': scopeA.versionId,
                'label': scopeA.label,
              },
              'revision': 1,
              'enrolled': true,
              'assigned': false,
              'baseline_linked': false,
              'history': [],
            }),
            200,
          );
        }),
      );
      addTearDown(repository.close);
      final key = repository.sessionKey;
      await repository.search(key, scopeA, '12345678909');
      await repository.inspect(key, scopeA, 'person');
      final command = OperationCommand(
        id: 'synthetic-command',
        sessionKey: key,
        scope: scopeA,
        action: OperationAction.enroll,
        reason: 'Synthetic reason',
        personId: 'person',
        expectedRevision: 0,
      );
      await repository.execute(command);
      await repository.execute(command);
      expect(bodies[2], bodies[3]);
      auth.generation++;
      await expectLater(
        repository.inspect(key, scopeA, 'person'),
        throwsA(isA<OperationFailure>()),
      );
      expect(bodies, hasLength(4));
    },
  );
}
