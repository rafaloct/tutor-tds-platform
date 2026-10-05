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

class FailingTokenStore extends MemoryTokenStore {
  Object? readError;
  Object? writeError;
  Object? clearError;
  @override
  Future<AuthTokens?> read() async {
    if (readError != null) throw readError!;
    return super.read();
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    if (writeError != null) throw writeError!;
    return super.write(tokens);
  }

  @override
  Future<void> clear() async {
    if (clearError != null) throw clearError!;
    return super.clear();
  }
}

String unverifiedToken(Object? payload) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}.signature';

MemoryTokenStore storedSession() => MemoryTokenStore()
  ..value = const AuthTokens(
    accessToken: 'access-current',
    refreshToken: 'refresh-current',
  );

Matcher fallbackError(bool allowed) => isA<AuthException>().having(
  (error) => error.allowOfflineFallback,
  'allowOfflineFallback',
  allowed,
);

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
  for (final status in [200, 401]) {
    test(
      'late refresh $status cannot restore logout or clear next login',
      () async {
        final store = storedSession();
        final started = Completer<void>();
        final response = Completer<http.Response>();
        final repository = AuthRepository(
          apiUrl: 'https://api.example',
          tokenStore: store,
          client: MockClient((request) async {
            if (request.url.path == '/auth/refresh') {
              started.complete();
              return response.future;
            }
            return http.Response(sessionJson(accessToken: 'next-account'), 200);
          }),
        );
        final refresh = repository.refresh();
        final rejected = expectLater(refresh, throwsA(fallbackError(false)));
        await started.future;
        await repository.logout();
        await repository.login(cpf: 'synthetic', password: 'synthetic');
        response.complete(http.Response(sessionJson(), status));
        await rejected;
        expect(store.value!.accessToken, 'next-account');
        expect(store.writes, 1);
        repository.dispose();
      },
    );
  }
  test('logout rejects pending login and authenticated response', () async {
    final store = storedSession();
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final repository = AuthRepository(
      apiUrl: 'https://api.example',
      tokenStore: store,
      client: MockClient((_) async {
        started.complete();
        return response.future;
      }),
    );
    final login = repository.login(cpf: 'synthetic', password: 'synthetic');
    final rejected = expectLater(login, throwsA(fallbackError(false)));
    await started.future;
    await repository.logout();
    response.complete(http.Response(sessionJson(), 200));
    await rejected;
    expect(store.value, isNull);
    expect(store.writes, 0);
    store.value = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    final result = Completer<http.Response>();
    final requested = Completer<void>();
    final request = repository.authorized((_) {
      requested.complete();
      return result.future;
    });
    final stale = expectLater(request, throwsA(fallbackError(false)));
    await requested.future;
    await repository.logout();
    result.complete(http.Response('{}', 200));
    await stale;
    repository.dispose();
  });
  test(
    'localUserId only decodes subject and performs no network or writes',
    () async {
      final store = MemoryTokenStore()
        ..value = AuthTokens(
          accessToken: unverifiedToken({'sub': 'owner-1', 'role': 'admin'}),
          refreshToken: 'refresh',
        );
      final repository = AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: store,
        client: MockClient(
          (_) async => throw StateError('Must not call network'),
        ),
      );
      expect(await repository.localUserId(), 'owner-1');
      expect(store.writes, 0);
      expect(store.clears, 0);
      repository.dispose();
    },
  );

  test(
    'localUserId rejects malformed tokens, absent and non-string subjects',
    () async {
      final store = MemoryTokenStore();
      final repository = AuthRepository(apiUrl: '', tokenStore: store);
      expect(await repository.localUserId(), isNull);
      for (final token in [
        '',
        'not-jwt',
        'a.b',
        'a.b.c.d',
        'a.%%%.c',
        '.e30.signature',
        'header.${base64Url.encode([255])}.signature',
        unverifiedToken([]),
        unverifiedToken(null),
        unverifiedToken({}),
        unverifiedToken({'sub': null}),
        unverifiedToken({'sub': 123}),
        unverifiedToken({'sub': ''}),
        unverifiedToken({'sub': '   '}),
      ]) {
        store.value = AuthTokens(accessToken: token, refreshToken: 'refresh');
        expect(await repository.localUserId(), isNull);
      }
      repository.dispose();
    },
  );

  test(
    'localUserId reflects token replacement and logout immediately',
    () async {
      final store = MemoryTokenStore()
        ..value = AuthTokens(
          accessToken: unverifiedToken({'sub': 'owner-1'}),
          refreshToken: 'refresh',
        );
      final repository = AuthRepository(apiUrl: '', tokenStore: store);
      expect(await repository.localUserId(), 'owner-1');
      store.value = AuthTokens(
        accessToken: unverifiedToken({'sub': 'owner-2'}),
        refreshToken: 'refresh-next',
      );
      expect(await repository.localUserId(), 'owner-2');
      await repository.logout();
      expect(await repository.localUserId(), isNull);
      repository.dispose();
    },
  );

  for (final refresh in [false, true]) {
    final operation = refresh ? 'refresh' : 'currentUser';
    test(
      '$operation permits fallback only for transport timeout/client errors',
      () async {
        for (final error in [
          TimeoutException('network detail'),
          http.ClientException('network detail'),
        ]) {
          final store = storedSession();
          final repository = AuthRepository(
            apiUrl: 'https://api.example',
            tokenStore: store,
            client: MockClient((_) async => throw error),
          );
          await expectLater(
            refresh ? repository.refresh() : repository.currentUser(),
            throwsA(fallbackError(true)),
          );
          expect(store.clears, 0);
          repository.dispose();
        }
      },
    );
    test(
      '$operation denies fallback for rejected HTTP responses and malformed data',
      () async {
        for (final response in [
          http.Response('private details', 401),
          http.Response('private details', 403),
          http.Response('private details', 500),
          http.Response('not-json', 200),
          http.Response('[]', 200),
          http.Response('{}', 200),
        ]) {
          final store = storedSession();
          final repository = AuthRepository(
            apiUrl: 'https://api.example',
            tokenStore: store,
            client: MockClient((request) async {
              if (!refresh && request.url.path == '/auth/refresh') {
                return http.Response(sessionJson(), 200);
              }
              return response;
            }),
          );
          await expectLater(
            refresh ? repository.refresh() : repository.currentUser(),
            throwsA(fallbackError(false)),
          );
          repository.dispose();
        }
      },
    );
  }

  test(
    'storage failures never enable fallback even when they are timeouts',
    () async {
      for (final failure in ['read', 'write', 'clear']) {
        final store = FailingTokenStore()
          ..value = const AuthTokens(
            accessToken: 'access-current',
            refreshToken: 'refresh-current',
          );
        final timeout = TimeoutException('secure storage timeout');
        if (failure == 'read') store.readError = timeout;
        if (failure == 'write') store.writeError = timeout;
        if (failure == 'clear') store.clearError = timeout;
        final repository = AuthRepository(
          apiUrl: 'https://api.example',
          tokenStore: store,
          client: MockClient(
            (_) async => failure == 'clear'
                ? http.Response('{}', 403)
                : http.Response(sessionJson(), 200),
          ),
        );
        await expectLater(repository.refresh(), throwsA(fallbackError(false)));
        if (failure == 'read') {
          await expectLater(
            repository.localUserId(),
            throwsA(fallbackError(false)),
          );
          await expectLater(
            repository.currentUser(),
            throwsA(fallbackError(false)),
          );
        }
        repository.dispose();
      }
    },
  );

  test(
    'currentUser propagates refresh transport failure without losing session',
    () async {
      final store = storedSession();
      final repository = AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: store,
        client: MockClient((request) async {
          if (request.url.path == '/auth/refresh') {
            throw TimeoutException('offline');
          }
          return http.Response('{}', 401);
        }),
      );
      await expectLater(repository.currentUser(), throwsA(fallbackError(true)));
      expect(store.clears, 0);
      repository.dispose();
    },
  );

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

  test(
    'registro envia código somente no contrato e salva apenas tokens',
    () async {
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
        activationCode: 'codigo-ativacao-unico',
      );

      expect(sent['password'], 'senha-enviada-uma-vez');
      expect(sent['activation_token'], 'codigo-ativacao-unico');
      expect(session.user.name, 'Pessoa de Teste');
      expect(store.writes, 1);
      expect(store.value?.accessToken, 'access-new');
      expect(store.value?.refreshToken, 'refresh-new');
      expect(store.value.toString(), isNot(contains('codigo-ativacao-unico')));
    },
  );

  test(
    'registro com código rejeitado não expõe resposta remota nem persiste código',
    () async {
      const activationCode = 'codigo-que-nao-pode-vazar';
      final store = MemoryTokenStore();
      final repository = AuthRepository(
        apiUrl: 'https://api.example',
        client: MockClient((request) async {
          expect(jsonDecode(request.body)['activation_token'], activationCode);
          return http.Response('token=$activationCode', 403);
        }),
        tokenStore: store,
      );

      await expectLater(
        repository.register(
          name: 'Pessoa de Teste',
          cpf: '123.456.789-09',
          phone: '61999990000',
          password: 'senha-enviada-uma-vez',
          activationCode: activationCode,
        ),
        throwsA(
          isA<AuthException>()
              .having((error) => error.message, 'message', contains('ativação'))
              .having(
                (error) => error.message,
                'message',
                isNot(contains(activationCode)),
              ),
        ),
      );
      expect(store.value, isNull);
      expect(store.writes, 0);
      repository.dispose();
    },
  );

  test('login com 403 não menciona código de ativação', () async {
    final store = MemoryTokenStore();
    final repository = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((request) async {
        expect(request.url.path, '/auth/login');
        return http.Response('{"detail":"pending"}', 403);
      }),
      tokenStore: store,
    );

    await expectLater(
      repository.login(cpf: '12345678909', password: 'senha-de-teste'),
      throwsA(
        isA<AuthException>()
            .having((e) => e.message, 'message', contains('liberada'))
            .having((e) => e.message, 'message', isNot(contains('código'))),
      ),
    );
    expect(store.writes, 0);
    repository.dispose();
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

  test('exclusão usa Bearer e limpa a sessão segura', () async {
    final store = MemoryTokenStore()
      ..value = const AuthTokens(
        accessToken: 'access-current',
        refreshToken: 'refresh-current',
      );
    final repository = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/auth/me');
        expect(request.headers['Authorization'], 'Bearer access-current');
        return http.Response('', 204);
      }),
      tokenStore: store,
    );

    expect(await repository.hasSession(), isTrue);
    await repository.deleteAccount();

    expect(store.value, isNull);
    expect(store.clears, 1);
    expect(await repository.hasSession(), isFalse);
  });

  test('exclusão com vínculo preserva a sessão e orienta suporte', () async {
    final store = MemoryTokenStore()
      ..value = const AuthTokens(
        accessToken: 'access-current',
        refreshToken: 'refresh-current',
      );
    final repository = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response('{}', 409)),
      tokenStore: store,
    );

    await expectLater(
      repository.deleteAccount(),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          contains('suporte TDS'),
        ),
      ),
    );
    expect(store.value, isNotNull);
    expect(store.clears, 0);
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
