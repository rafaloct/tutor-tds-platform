import 'dart:convert';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenStore implements AuthTokenStore {
  AuthTokens? value = const AuthTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );

  @override
  Future<void> clear() async => value = null;
  @override
  Future<AuthTokens?> read() async => value;
  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

Map<String, dynamic> classroomJson() => {
  'id': 'turma-1',
  'program_id': 'programa-1',
  'course_id': 'agricultura',
  'teacher_id': 'prof-1',
  'name': 'Turma Jalapão',
  'start_date': '2026-09-01',
  'end_date': '2026-12-01',
  'status': 'active',
};

void main() {
  test('lista somente turmas visíveis usando autenticação existente', () async {
    final auth = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response('{}', 500)),
      tokenStore: _TokenStore(),
    );
    final repository = ClassroomRepository(
      apiUrl: 'https://api.example/',
      authRepository: auth,
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://api.example/classes');
        expect(request.headers['authorization'], 'Bearer access-token');
        return http.Response(
          jsonEncode({
            'classes': [classroomJson()],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final classes = await repository.classrooms();
    expect(classes.single.name, 'Turma Jalapão');
    expect(classes.single.studentIds, isEmpty);
  });

  test('propaga detalhe seguro da API em falha de acesso', () async {
    final auth = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response('{}', 500)),
      tokenStore: _TokenStore(),
    );
    final repository = ClassroomRepository(
      apiUrl: 'https://api.example',
      authRepository: auth,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Acesso não autorizado para esta turma.'}),
          403,
        ),
      ),
    );

    await expectLater(
      repository.dashboard('turma-1'),
      throwsA(
        isA<ClassroomException>().having(
          (error) => error.message,
          'message',
          'Acesso não autorizado para esta turma.',
        ),
      ),
    );
  });
}
