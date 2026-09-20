import 'package:cartilhas_app/features/analytics/app_telemetry_service.dart';
import 'package:cartilhas_app/features/analytics/telemetry_route.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'registra página, recurso e funcionalidade na fila autenticada',
    () async {
      final auth = AuthRepository(apiUrl: '');
      final sync = LearningEventSyncService(
        apiUrl: '',
        authRepository: auth,
        consentChecker: () async => true,
      );
      final telemetry = AppTelemetryService(
        syncService: sync,
        consentChecker: () async => true,
        sessionId: 'app-session',
      );

      final queued = await telemetry.trackPage(
        pageId: 'assessment',
        courseId: 'course-1',
        resourceId: 'ai_quiz',
        featureId: 'assessment',
      );
      final events = await const LearningEventQueue().pending();

      expect(queued, 3);
      expect(events.map((event) => event.type), [
        LearningEventType.pageViewed,
        LearningEventType.resourceOpened,
        LearningEventType.featureUsed,
      ]);
      expect(events.map((event) => event.payload), [
        {'page_id': 'assessment'},
        {'resource_id': 'ai_quiz'},
        {'feature_id': 'assessment'},
      ]);
      expect(events.map((event) => event.eventId).toSet(), hasLength(3));

      await sync.flush();
      sync.dispose();
      auth.dispose();
    },
  );

  test('consentimento negado não persiste telemetria', () async {
    final auth = AuthRepository(apiUrl: '');
    final sync = LearningEventSyncService(
      apiUrl: '',
      authRepository: auth,
      consentChecker: () async => false,
    );
    final telemetry = AppTelemetryService(
      syncService: sync,
      consentChecker: () async => false,
      sessionId: 'app-session',
    );

    expect(await telemetry.trackFeature(featureId: 'profile_saved'), 0);
    expect(await const LearningEventQueue().pending(), isEmpty);

    await sync.flush();
    sync.dispose();
    auth.dispose();
  });

  test('observador registra entrada e retorno das rotas nomeadas', () async {
    final auth = AuthRepository(apiUrl: '');
    final sync = LearningEventSyncService(
      apiUrl: '',
      authRepository: auth,
      consentChecker: () async => true,
    );
    final telemetry = AppTelemetryService(
      syncService: sync,
      consentChecker: () async => true,
      sessionId: 'navigation-session',
    );
    final observer = TelemetryNavigatorObserver(telemetry);

    final root = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/'),
      builder: (_) => const SizedBox.shrink(),
    );
    final summary = trackedRoute<void>(
      pageId: 'summary',
      courseId: 'course-1',
      resourceId: 'ai_summary',
      featureId: 'summary',
      builder: (_) => const SizedBox.shrink(),
    );
    observer.didPush(root, null);
    observer.didPush(summary, root);
    observer.didPop(summary, root);
    await observer.settled;

    final events = await const LearningEventQueue().pending();
    expect(
      events
          .where((event) => event.type == LearningEventType.pageViewed)
          .map((event) => event.payload['page_id']),
      ['welcome', 'summary', 'welcome'],
    );
    expect(
      events
          .where((event) => event.type == LearningEventType.resourceOpened)
          .single
          .payload,
      {'resource_id': 'ai_summary'},
    );
    expect(
      events
          .where((event) => event.type == LearningEventType.featureUsed)
          .single
          .payload,
      {'feature_id': 'summary'},
    );

    await sync.flush();
    sync.dispose();
    auth.dispose();
  });
}
