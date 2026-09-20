import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_lifecycle.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tenta no primeiro frame e novamente ao retomar o app', (
    tester,
  ) async {
    const queue = LearningEventQueue();
    await queue.enqueue(
      LearningEvent.forSession(
        type: LearningEventType.lessonStarted,
        courseId: 'agricultura-sustentavel',
        sessionId: 'sessao-offline',
        occurredAt: DateTime.utc(2026, 9, 20, 10),
      ),
    );
    var requests = 0;
    final authRepository = AuthRepository(
      apiUrl: 'https://api.example',
      tokenStore: _TokenStore(),
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    final service = LearningEventSyncService(
      apiUrl: 'https://api.example',
      authRepository: authRepository,
      queue: queue,
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', requests == 1 ? 503 : 201);
      }),
      consentChecker: () async => true,
    );

    await tester.pumpWidget(
      Provider.value(
        value: service,
        child: const LearningEventSyncLifecycle(
          child: MaterialApp(home: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(await queue.pending(), hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(await queue.pending(), isEmpty);

    await tester.pumpWidget(const SizedBox());
    service.dispose();
    authRepository.dispose();
  });
}
