import 'dart:async';
import 'dart:convert';
import 'package:cartilhas_app/features/analytics/app_telemetry_service.dart';
import 'package:cartilhas_app/features/analytics/screen_engagement_clock.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Tokens implements AuthTokenStore {
  AuthTokens? value;
  @override
  Future<AuthTokens?> read() async => value;
  @override
  Future<void> write(AuthTokens tokens) async {
    value = tokens;
  }

  @override
  Future<void> clear() async {
    value = null;
  }

  void person(String id) {
    value = AuthTokens(
      accessToken:
          'h.${base64Url.encode(utf8.encode(jsonEncode({'sub': id})))}.s',
      refreshToken: 'refresh',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'foreground excludes pause, caps idle, retains fractions and resumes on touch',
    () {
      var elapsed = Duration.zero;
      final meter = ScreenEngagementClock(() => elapsed)..start();
      elapsed += const Duration(milliseconds: 600);
      expect(meter.checkpoint(), 0);
      elapsed += const Duration(milliseconds: 600);
      expect(meter.checkpoint(), 1);
      elapsed += const Duration(seconds: 90);
      expect(meter.checkpoint(), 59);
      elapsed += const Duration(seconds: 10);
      expect(meter.checkpoint(), 0);
      meter.touch();
      elapsed += const Duration(seconds: 5);
      expect(meter.checkpoint(), 5);
      meter.setForeground(false);
      elapsed += const Duration(hours: 1);
      expect(meter.checkpoint(), 0);
      meter.setForeground(true);
      elapsed += const Duration(seconds: 3);
      expect(meter.checkpoint(), 3);
    },
  );

  test(
    'screen time is owned, survives serialization and drops account-switch interval',
    () async {
      var elapsed = Duration.zero;
      final store = Tokens()..person('alice');
      final auth = AuthRepository(
        apiUrl: 'https://synthetic.example/api',
        tokenStore: store,
      );
      final sync = LearningEventSyncService(
        apiUrl: auth.apiUrl,
        authRepository: auth,
        consentChecker: () async => false,
      );
      final telemetry = AppTelemetryService(
        syncService: sync,
        journeyEnabled: true,
        elapsed: () => elapsed,
        consentChecker: () async => true,
      );
      await telemetry.screenShown(pageId: 'home');
      elapsed += const Duration(seconds: 12);
      expect(await telemetry.checkpointScreen(), 1);
      elapsed += const Duration(seconds: 8);
      await auth.logout();
      store.person('bob');
      expect(await telemetry.checkpointScreen(), 0);
      await telemetry.heartbeatScreen();
      elapsed += const Duration(seconds: 5);
      expect(await telemetry.checkpointScreen(), 1);
      final events = await const LearningEventQueue().pending();
      expect(events.map((e) => e.activeSeconds), [12, 5]);
      expect(events.map((e) => e.localOwnerId), ['alice', 'bob']);
      expect(
        events.every(
          (e) => e.isTelemetry && e.type == LearningEventType.screenEngagement,
        ),
        isTrue,
      );
      expect(events.first.toJson().containsKey('local_owner_id'), isFalse);
      await telemetry.screenShown(pageId: null);
      elapsed += const Duration(seconds: 9);
      expect(await telemetry.checkpointScreen(), 0);
      sync.dispose();
      auth.dispose();
    },
  );

  test(
    'pending consent cannot attribute old page to newly logged-in user',
    () async {
      var elapsed = Duration.zero;
      final store = Tokens()..person('alice');
      final auth = AuthRepository(
        apiUrl: 'https://synthetic.example/api',
        tokenStore: store,
      );
      final sync = LearningEventSyncService(
        apiUrl: auth.apiUrl,
        authRepository: auth,
        consentChecker: () async => false,
      );
      final consent = Completer<bool>();
      final started = Completer<void>();
      final telemetry = AppTelemetryService(
        syncService: sync,
        journeyEnabled: true,
        elapsed: () => elapsed,
        consentChecker: () {
          if (!started.isCompleted) started.complete();
          return consent.future;
        },
      );
      final page = telemetry.screenShown(pageId: 'tutor');
      await started.future;
      await auth.logout();
      store.person('bob');
      consent.complete(true);
      await page;
      elapsed += const Duration(seconds: 10);
      expect(await telemetry.checkpointScreen(), 0);
      expect(await const LearningEventQueue().pending(), isEmpty);
      sync.dispose();
      auth.dispose();
    },
  );
}
