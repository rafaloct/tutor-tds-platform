import 'dart:async';

import 'package:cartilhas_app/features/analytics/google_usage_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements GoogleAnalyticsGateway {
  final calls = <String>[];
  bool failConsent = false;
  bool failLog = false;

  @override
  Future<void> setConsent(bool enabled) async {
    calls.add('consent:$enabled');
    if (failConsent) throw StateError('SDK unavailable');
  }

  @override
  Future<void> reset() async => calls.add('reset');

  @override
  Future<void> log(String event, String target) async {
    if (failLog) throw StateError('SDK unavailable');
    calls.add('$event:$target');
  }
}

void main() {
  late _Gateway gateway;
  late GoogleUsageAnalytics analytics;
  late bool stored;

  setUp(() {
    stored = false;
    gateway = _Gateway();
    analytics = GoogleUsageAnalytics(
      gateway: gateway,
      readConsent: () async => stored,
      writeConsent: (value) async { stored = value; },
    );
  });

  tearDown(() => analytics.dispose());

  test('no events before consent, including first launch', () async {
    await analytics.track('page_viewed', 'home');
    expect(gateway.calls, isEmpty);
    await analytics.initialize();
    await analytics.track('page_viewed', 'home');
    expect(gateway.calls, ['consent:false', 'reset']);
    expect(analytics.consentGranted, isFalse);
  });

  test('restores only the dedicated consent and sends categorical events', () async {
    stored = true;
    await analytics.initialize();
    await analytics.track('page_viewed', 'home');
    await analytics.track('resource_opened', 'ai_quiz');
    expect(gateway.calls, [
      'consent:true', 'page_viewed:home', 'resource_opened:ai_quiz',
    ]);
  });

  test('rejects arbitrary identifiers, text and academic events', () async {
    await analytics.setConsent(true);
    for (final target in ['12345678909', 'Maria Silva', 'student-1',
        'home?cpf=123', 'course-private', 'What is my grade?']) {
      await analytics.track('page_viewed', target);
    }
    await analytics.track('assessment_completed', 'assessment');
    await analytics.track('feature_used', 'presence_decision_recorded');
    expect(gateway.calls, ['consent:true']);
  });

  test('revocation cancels queued events and resets SDK data', () async {
    await analytics.setConsent(true);
    final queued = analytics.track('page_viewed', 'home');
    final revoked = analytics.setConsent(false);
    expect(analytics.consentGranted, isFalse);
    await Future.wait([queued, revoked]);
    await analytics.track('page_viewed', 'home');
    expect(gateway.calls, ['consent:true', 'consent:false', 'reset']);
    expect(stored, isFalse);
  });

  test('late startup consent cannot overwrite a newer refusal', () async {
    final gate = Completer<bool>();
    final delayed = GoogleUsageAnalytics(
      gateway: gateway,
      readConsent: () => gate.future,
      writeConsent: (value) async { stored = value; },
    );
    final startup = delayed.initialize();
    await Future<void>.delayed(Duration.zero);
    final refusal = delayed.setConsent(false);
    gate.complete(true);
    await Future.wait([startup, refusal]);
    expect(delayed.consentGranted, isFalse);
    expect(gateway.calls, ['consent:false', 'reset']);
    delayed.dispose();
  });

  test('failed SDK initialization cannot enable app events', () async {
    gateway.failConsent = true;
    stored = true;
    await expectLater(analytics.initialize(), throwsStateError);
    await analytics.track('page_viewed', 'home');
    expect(analytics.consentGranted, isFalse);
    expect(gateway.calls, ['consent:true']);
  });

  test('SDK event failure does not poison later revocation', () async {
    await analytics.setConsent(true);
    gateway.failLog = true;
    await expectLater(analytics.track('page_viewed', 'home'), throwsStateError);
    await analytics.setConsent(false);
    expect(gateway.calls.last, 'reset');
    expect(analytics.consentGranted, isFalse);
  });

  test('repeated revocation is safe and does not duplicate resets', () async {
    await analytics.setConsent(true);
    await analytics.setConsent(false);
    await analytics.setConsent(false);
    expect(gateway.calls.where((call) => call == 'reset'), hasLength(1));
  });
}
