import 'dart:async';
import 'dart:convert';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryTokenStore implements AuthTokenStore {
  AuthTokens? value;
  var writes = 0;
  var clears = 0;

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<void> write(AuthTokens tokens) async {
    writes++;
    value = tokens;
  }
}

String sessionJson({
  String accessToken = 'access-new',
  String refreshToken = 'refresh-new',
}) => jsonEncode({
  'access_token': accessToken,
  'refresh_token': refreshToken,
  'token_type': 'bearer',
  'expires_in': 900,
  'user': {'id': 'user-1', 'name': 'Pessoa de Teste', 'role': 'student'},
});

void main() {
  test('API vazia preserva modo offline sem chamada de rede', () async {
    var networkCalled = false;
    final repository = AuthRepository(
      apiUrl: '',
      client: MockClient((_) async {
        networkCalled = true;
        return http.Response('{}', 500);
      }),
      tokenStore: MemoryTokenStore(),
    );

    await expectLater(
      repository.login(cpf: '12345678909', password: 'nao-persistir'),
      throwsA(isA<AuthException>()),
    );
    expect(networkCalled, isFalse);
  });

  test('registro salva somente tokens no armazenamento injetado', () async {
    final store = MemoryTokenStore();
    late Map<String, dynamic> sent;
    final repository = AuthRepository(
      apiUrl: 'https://api.example/',
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://api.example/auth/register');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(sessionJson(), 201);
      }),
      tokenStore: store,
    );

    final session = await repository.register(
      name: 'Pessoa de Teste',
      cpf: '123.456.789-09',
      phone: '61999990000',
      password: 'senha-enviada-uma-vez',
    );

    expect(sent['password'], 'senha-enviada-uma-vez');
    expect(session.user.name, 'Pessoa de Teste');
    expect(store.writes, 1);
    expect(store.value?.accessToken, 'access-new');
    expect(store.value?.refreshToken, 'refresh-new');
  });

  test(
    '401 renova uma vez e repete a requisição com novo access token',
    () async {
      final store = MemoryTokenStore()
        ..value = const AuthTokens(
          accessToken: 'access-old',
          refreshToken: 'refresh-old',
        );
      var refreshCalls = 0;
      final repository = AuthRepository(
        apiUrl: 'https://api.example',
        client: MockClient((request) async {
          refreshCalls++;
          expect(request.url.path, '/auth/refresh');
          expect(jsonDecode(request.body), {'refresh_token': 'refresh-old'});
          return http.Response(sessionJson(), 200);
        }),
        tokenStore: store,
      );
      final attemptedTokens = <String>[];

      final response = await repository.authorized((token) async {
        attemptedTokens.add(token);
        return http.Response('', attemptedTokens.length == 1 ? 401 : 200);
      });

      expect(response.statusCode, 200);
      expect(attemptedTokens, ['access-old', 'access-new']);
      expect(refreshCalls, 1);
    },
  );

  test('segundo 401 não inicia loop de refresh', () async {
    final store = MemoryTokenStore()
      ..value = const AuthTokens(
        accessToken: 'access-old',
        refreshToken: 'refresh-old',
      );
    var refreshCalls = 0;
    var requestCalls = 0;
    final repository = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async {
        refreshCalls++;
        return http.Response(sessionJson(), 200);
      }),
      tokenStore: store,
    );

    final response = await repository.authorized((_) async {
      requestCalls++;
      return http.Response('', 401);
    });

    expect(response.statusCode, 401);
    expect(requestCalls, 2);
    expect(refreshCalls, 1);
  });

  test('/auth/me usa Bearer e retorna somente usuário público', () async {
    final store = MemoryTokenStore()
      ..value = const AuthTokens(
        accessToken: 'access-current',
        refreshToken: 'refresh-current',
      );
    final repository = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((request) async {
        expect(request.url.path, '/auth/me');
        expect(request.headers['Authorization'], 'Bearer access-current');
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'name': 'Pessoa de Teste',
            'role': 'student',
          }),
          200,
        );
      }),
      tokenStore: store,
    );

    final user = await repository.currentUser();

    expect(user.id, 'user-1');
    expect(user.role, 'student');
    expect(store.value?.refreshToken, 'refresh-current');
  });

  test('requisições simultâneas compartilham uma única renovação', () async {
    final store = MemoryTokenStore()
      ..value = const AuthTokens(
        accessToken: 'access-old',
        refreshToken: 'refresh-old',
      );
    final releaseRefresh = Completer<void>();
    var refreshCalls = 0;
    final repository = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async {
        refreshCalls++;
        await releaseRefresh.future;
        return http.Response(sessionJson(), 200);
      }),
      tokenStore: store,
    );

    Future<http.Response> protectedRequest(String token) async =>
        http.Response('', token == 'access-old' ? 401 : 200);

    final first = repository.authorized(protectedRequest);
    final second = repository.authorized(protectedRequest);
    await Future<void>.delayed(Duration.zero);
    expect(refreshCalls, 1);
    releaseRefresh.complete();

    final responses = await Future.wait([first, second]);
    expect(responses.map((response) => response.statusCode), [200, 200]);
    expect(refreshCalls, 1);
  });

  test('refresh rejeitado limpa tokens sem expor resposta remota', () async {
    final store = MemoryTokenStore()
      ..value = const AuthTokens(
        accessToken: 'access-old',
        refreshToken: 'refresh-sensitive',
      );
    final repository = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient(
        (_) async => http.Response('refresh-sensitive internal error', 401),
      ),
      tokenStore: store,
    );

    Object? captured;
    try {
      await repository.refresh();
    } on Object catch (error) {
      captured = error;
    }

    expect(captured, isA<AuthException>());
    expect(captured.toString(), isNot(contains('refresh-sensitive')));
    expect(store.value, isNull);
    expect(store.clears, 1);
  });
}
