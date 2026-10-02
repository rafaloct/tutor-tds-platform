import 'dart:async';

import 'package:cartilhas_app/features/analytics/app_telemetry_service.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/courses/application/course_pdf_controller.dart';
import 'package:cartilhas_app/features/courses/presentation/course_pdf_button.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_queue.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/services/privacy_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screen_engagement_test.dart' show Tokens;

const _url = 'https://drive.google.com/file/d/synthetic-pdf/view';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rejects invalid links and coalesces concurrent requests', () async {
    final launched = <Uri>[];
    final result = Completer<bool>();
    final controller = CoursePdfController(
      launch: (uri) {
        launched.add(uri);
        return result.future;
      },
    );
    for (final url in [
      null,
      '',
      'not-a-url',
      'http://host/a.pdf',
      'file:///a.pdf',
      'https://user:secret@host/a.pdf',
    ]) {
      expect(
        await controller.open(url: url, courseId: 'course'),
        CoursePdfResult.invalidLink,
      );
    }
    expect(launched, isEmpty);
    final first = controller.open(url: _url, courseId: 'course');
    expect(
      await controller.open(url: _url, courseId: 'course'),
      CoursePdfResult.busy,
    );
    result.complete(true);
    expect(await first, CoursePdfResult.requested);
    expect(launched, [Uri.parse(_url)]);
    expect(controller.isOpening, isFalse);
  });

  for (final throws in [false, true]) {
    test('launcher failure is recoverable (throws=$throws)', () async {
      var calls = 0;
      final controller = CoursePdfController(
        launch: (_) async {
          if (++calls > 1) return true;
          if (throws) throw StateError('platform unavailable');
          return false;
        },
      );
      expect(
        await controller.open(url: _url, courseId: 'course'),
        CoursePdfResult.unavailable,
      );
      expect(controller.isOpening, isFalse);
      expect(
        await controller.open(url: _url, courseId: 'course'),
        CoursePdfResult.requested,
      );
    });
  }

  for (final scenario in [
    (
      name: 'legacy consent only',
      enabled: true,
      consent: false,
      owner: true,
      count: 0,
    ),
    (
      name: 'flag disabled',
      enabled: false,
      consent: true,
      owner: true,
      count: 0,
    ),
    (name: 'no account', enabled: true, consent: true, owner: false, count: 0),
    (
      name: 'consenting account',
      enabled: true,
      consent: true,
      owner: true,
      count: 1,
    ),
  ]) {
    test('PDF request respects ${scenario.name}', () async {
      SharedPreferences.setMockInitialValues({
        PrivacyPreferences.consentKey: true,
        PrivacyPreferences.journeyConsentKey: scenario.consent,
      });
      final tokens = Tokens();
      if (scenario.owner) tokens.person('synthetic-learner');
      final auth = AuthRepository(
        apiUrl: 'https://synthetic.example/api',
        tokenStore: tokens,
      );
      final sync = LearningEventSyncService(
        apiUrl: auth.apiUrl,
        authRepository: auth,
        consentChecker: () async => false,
      );
      addTearDown(sync.dispose);
      addTearDown(auth.dispose);
      final telemetry = AppTelemetryService(
        syncService: sync,
        journeyEnabled: scenario.enabled,
        consentChecker: () =>
            PrivacyPreferences.hasConsent(journeyEnabled: true),
      );
      var launches = 0;
      final controller = CoursePdfController(
        launch: (_) async {
          launches++;
          return true;
        },
      );
      expect(
        await controller.open(
          url: _url,
          courseId: 'ia-cartilha',
          telemetry: telemetry,
        ),
        CoursePdfResult.requested,
      );
      // Allow the nonblocking local consent/queue write to settle.
      await Future<void>.delayed(Duration.zero);
      final events = await const LearningEventQueue().pending();
      expect(launches, 1);
      expect(events, hasLength(scenario.count));
      if (events.isNotEmpty) {
        final event = events.single;
        expect(event.localOwnerId, 'synthetic-learner');
        expect(event.courseId, 'ia-cartilha');
        expect(event.activeSeconds, isNull);
        expect(event.isTelemetry, isTrue);
        expect(event.toJson()['payload'], {
          'feature_id': 'course_pdf_open_requested',
        });
        expect(event.toJson().toString(), isNot(contains(_url)));
      }
    });
  }

  test('failed consent lookup never blocks opening the PDF', () async {
    final auth = AuthRepository(
      apiUrl: 'https://synthetic.example/api',
      tokenStore: Tokens()..person('learner'),
    );
    final sync = LearningEventSyncService(
      apiUrl: auth.apiUrl,
      authRepository: auth,
      consentChecker: () async => false,
    );
    addTearDown(sync.dispose);
    addTearDown(auth.dispose);
    final telemetry = AppTelemetryService(
      syncService: sync,
      journeyEnabled: true,
      consentChecker: () async => throw StateError('storage unavailable'),
    );
    expect(
      await CoursePdfController(
        launch: (_) async => true,
      ).open(url: _url, courseId: 'course', telemetry: telemetry),
      CoursePdfResult.requested,
    );
    await Future<void>.delayed(Duration.zero);
    expect(await const LearningEventQueue().pending(), isEmpty);
  });

  testWidgets(
    'existing PDF button handles failure and prevents duplicate taps',
    (tester) async {
      final launched = Completer<bool>();
      var calls = 0;
      final controller = CoursePdfController(
        launch: (_) {
          calls++;
          return launched.future;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoursePdfButton(
              course: Cartilha(
                id: 'ia-cartilha',
                title: 'IA',
                author: 'TDS',
                sections: [],
                downloadUrl: _url,
              ),
              controller: controller,
            ),
          ),
        ),
      );
      await tester.tap(find.text('PDF'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(calls, 1);
      launched.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.text('Não foi possível abrir o PDF. Tente novamente.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
