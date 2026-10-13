import 'package:cartilhas_app/features/analytics/app_telemetry_service.dart';
import 'package:cartilhas_app/features/analytics/telemetry_route.dart';
import 'package:cartilhas_app/features/analytics/google_usage_analytics.dart';
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

  test('Google consent is independent and academic IDs never reach its gateway', () async {
    final gateway = _GoogleGateway();
    final google = GoogleUsageAnalytics(
      gateway: gateway,
      readConsent: () async => false,
      writeConsent: (_) async {},
    );
    final auth = AuthRepository(apiUrl: '');
    final sync = LearningEventSyncService(apiUrl: '', authRepository: auth);
    final telemetry = AppTelemetryService(
      syncService: sync,
      googleAnalytics: google,
      consentChecker: () async => false,
    );
    await google.setConsent(true);
    expect(await telemetry.trackPage(
      pageId: 'home', courseId: 'private-course-id', resourceId: 'ai_quiz',
    ), 0);
    await Future<void>.delayed(Duration.zero);
    expect(gateway.events, ['page_viewed:home', 'resource_opened:ai_quiz']);
    expect(await const LearningEventQueue().pending(), isEmpty);
    await google.setConsent(false);
    await telemetry.trackPage(pageId: 'home');
    expect(gateway.events, hasLength(2));
    google.dispose();
    sync.dispose();
    auth.dispose();
  });

  test('Google outage cannot prevent the existing telemetry outbox', () async {
    final gateway = _GoogleGateway()..fail = true;
    final google = GoogleUsageAnalytics(
      gateway: gateway,
      readConsent: () async => false,
      writeConsent: (_) async {},
    );
    await google.setConsent(true);
    final auth = AuthRepository(apiUrl: '');
    final sync = LearningEventSyncService(apiUrl: '', authRepository: auth);
    final telemetry = AppTelemetryService(
      syncService: sync,
      googleAnalytics: google,
      consentChecker: () async => true,
    );
    expect(await telemetry.trackPage(pageId: 'home'), 1);
    await Future<void>.delayed(Duration.zero);
    expect(await const LearningEventQueue().pending(), hasLength(1));
    google.dispose();
    sync.dispose();
    auth.dispose();
  });

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

class _GoogleGateway implements GoogleAnalyticsGateway {
  final events = <String>[];
  bool fail = false;

  @override
  Future<void> setConsent(bool enabled) async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> log(String event, String target) async {
    if (fail) throw StateError('SDK unavailable');
    events.add('$event:$target');
  }
}
