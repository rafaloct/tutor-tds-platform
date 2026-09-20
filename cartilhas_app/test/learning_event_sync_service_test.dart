import 'dart:async';
import 'dart:convert';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryTokenStore implements AuthTokenStore {
  _MemoryTokenStore([this.value]);

  AuthTokens? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

const _oldTokens = AuthTokens(
  accessToken: 'access-old',
  refreshToken: 'refresh-old',
);

String _sessionJson() => jsonEncode({
  'access_token': 'access-new',
  'refresh_token': 'refresh-new',
  'token_type': 'bearer',
  'expires_in': 900,
  'user': {'id': 'user-1', 'name': 'Pessoa de Teste', 'role': 'student'},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const queue = LearningEventQueue();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  LearningEvent event(String session, LearningEventType type) =>
      LearningEvent.forSession(
        type: type,
        courseId: 'agricultura-sustentavel',
        sessionId: session,
        occurredAt: DateTime.utc(2026, 9, 20, 10),
      );

  AuthRepository auth({
    String apiUrl = 'https://api.example',
    AuthTokens? tokens = _oldTokens,
    http.Client? client,
  }) => AuthRepository(
    apiUrl: apiUrl,
    tokenStore: _MemoryTokenStore(tokens),
    client: client ?? MockClient((_) async => http.Response('{}', 500)),
  );

  Future<void> seedOne() =>
      queue.enqueue(event('sessao-1', LearningEventType.lessonStarted));

  test('sem consentimento não consulta sessão nem chama a API', () async {
    await seedOne();
    var requests = 0;
    var tokenReads = 0;
    final tokenStore = _CountingTokenStore(_oldTokens, () => tokenReads++);
    final service = LearningEventSyncService(
      apiUrl: 'https://api.example',
      authRepository: AuthRepository(
        apiUrl: 'https://api.example',
        tokenStore: tokenStore,
        client: MockClient((_) async => http.Response('{}', 500)),
      ),
      queue: queue,
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 201);
      }),
      consentChecker: () async => false,
    );

    expect(await service.flush(), 0);
    expect(requests, 0);
    expect(tokenReads, 0);
    expect(await queue.pending(), hasLength(1));
  });

  test('API vazia não chama rede e preserva a fila', () async {
    await seedOne();
    var requests = 0;
    final service = LearningEventSyncService(
      apiUrl: '',
      authRepository: auth(apiUrl: ''),
      queue: queue,
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 201);
      }),
      consentChecker: () async => true,
    );

    expect(await service.flush(), 0);
    expect(requests, 0);
    expect(await queue.pending(), hasLength(1));
  });

  test('sem sessão não chama /events e preserva a fila', () async {
    await seedOne();
    var requests = 0;
    final service = LearningEventSyncService(
      apiUrl: 'https://api.example',
      authRepository: auth(tokens: null),
      queue: queue,
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 201);
      }),
      consentChecker: () async => true,
    );

    expect(await service.flush(), 0);
    expect(requests, 0);
    expect(await queue.pending(), hasLength(1));
  });

  test('200 remove somente o evento confirmado e para no 5xx', () async {
    final first = event('sessao-1', LearningEventType.lessonStarted);
    final second = event('sessao-2', LearningEventType.lessonCompleted);
    await queue.enqueue(first);
    await queue.enqueue(second);
    var requests = 0;
    final service = LearningEventSyncService(
      apiUrl: 'https://api.example',
      authRepository: auth(),
      queue: queue,
      client: MockClient((request) async {
        requests++;
        expect(request.url.path, '/events');
        expect(request.headers['Authorization'], 'Bearer access-old');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          body['event_id'],
          requests == 1 ? first.eventId : second.eventId,
        );
        return http.Response('{}', requests == 1 ? 200 : 503);
      }),
      consentChecker: () async => true,
    );

    expect(await service.flush(), 1);
    expect(requests, 2);
    expect((await queue.pending()).map((item) => item.eventId), [
      second.eventId,
    ]);
  });

  test('201 confirma e remove o evento', () async {
    await seedOne();
    final service = LearningEventSyncService(
      apiUrl: 'https://api.example/',
      authRepository: auth(),
      queue: queue,
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://api.example/events');
        return http.Response('{}', 201);
      }),
      consentChecker: () async => true,
    );

    expect(await service.flush(), 1);
    expect(await queue.pending(), isEmpty);
  });

  test('401 usa refresh do AuthRepository e repete com novo token', () async {
    await seedOne();
    var refreshRequests = 0;
    var eventRequests = 0;
    final repository = auth(
      client: MockClient((request) async {
        refreshRequests++;
        expect(request.url.path, '/auth/refresh');
        return http.Response(_sessionJson(), 200);
      }),
    );
    final service = LearningEventSyncService(
      apiUrl: 'https://api.example',
      authRepository: repository,
      queue: queue,
      client: MockClient((request) async {
        eventRequests++;
        final expected = eventRequests == 1 ? 'access-old' : 'access-new';
        expect(request.headers['Authorization'], 'Bearer $expected');
        return http.Response('{}', eventRequests == 1 ? 401 : 201);
      }),
      consentChecker: () async => true,
    );

    expect(await service.flush(), 1);
    expect(eventRequests, 2);
    expect(refreshRequests, 1);
    expect(await queue.pending(), isEmpty);
  });

  test('409 não é sucesso, preserva a fila e interrompe o lote', () async {
    await queue.enqueue(event('sessao-1', LearningEventType.lessonStarted));
    await queue.enqueue(event('sessao-2', LearningEventType.lessonStarted));
    var requests = 0;
    final service = LearningEventSyncService(
      apiUrl: 'https://api.example',
      authRepository: auth(),
      queue: queue,
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 409);
      }),
      consentChecker: () async => true,
    );

    expect(await service.flush(), 0);
    expect(requests, 1);
    expect(await queue.pending(), hasLength(2));
  });

  test('flushes concorrentes compartilham uma única transmissão', () async {
    await seedOne();
    final release = Completer<void>();
    var requests = 0;
    final service = LearningEventSyncService(
      apiUrl: 'https://api.example',
      authRepository: auth(),
      queue: queue,
      client: MockClient((_) async {
        requests++;
        await release.future;
        return http.Response('{}', 201);
      }),
      consentChecker: () async => true,
    );

    final first = service.flush();
    final second = service.flush();
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    release.complete();

    expect(await Future.wait([first, second]), [1, 1]);
    expect(requests, 1);
    expect(await queue.pending(), isEmpty);
  });
}

class _CountingTokenStore extends _MemoryTokenStore {
  _CountingTokenStore(super.value, this.onRead);

  final void Function() onRead;

  @override
  Future<AuthTokens?> read() async {
    onRead();
    return super.read();
  }
}
