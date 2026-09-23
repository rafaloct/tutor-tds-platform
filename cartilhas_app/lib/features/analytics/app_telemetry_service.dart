import 'dart:async';

import '../../services/privacy_preferences.dart';
import '../learning_events/learning_event.dart';
import '../learning_events/learning_event_queue.dart';
import '../learning_events/learning_event_sync_service.dart';

typedef TelemetryConsentChecker = Future<bool> Function();

class AppTelemetryService {
  AppTelemetryService({
    required this.syncService,
    this.queue = const LearningEventQueue(),
    this.consentChecker = PrivacyPreferences.hasConsent,
    String? sessionId,
  }) : sessionId = sessionId ?? LearningEvent.newSessionId();

  static const applicationCourseId = '_app';

  final LearningEventSyncService syncService;
  final LearningEventQueue queue;
  final TelemetryConsentChecker consentChecker;
  final String sessionId;
  int _sequence = 0;

  Future<int> trackPage({
    required String pageId,
    String courseId = applicationCourseId,
    String? resourceId,
    String? featureId,
    bool includeAccessEvents = true,
  }) async {
    final targets = <(LearningEventType, String)>[
      (LearningEventType.pageViewed, pageId),
      if (includeAccessEvents && resourceId != null)
        (LearningEventType.resourceOpened, resourceId),
      if (includeAccessEvents && featureId != null)
        (LearningEventType.featureUsed, featureId),
    ];
    return _trackTargets(targets, courseId: courseId);
  }

  Future<int> trackFeature({
    required String featureId,
    String courseId = applicationCourseId,
  }) => _trackTargets([
    (LearningEventType.featureUsed, featureId),
  ], courseId: courseId);

  Future<int> trackResource({
    required String resourceId,
    String courseId = applicationCourseId,
  }) => _trackTargets([
    (LearningEventType.resourceOpened, resourceId),
  ], courseId: courseId);

  Future<int> _trackTargets(
    List<(LearningEventType, String)> targets, {
    required String courseId,
  }) async {
    if (!await consentChecker()) return 0;
    final owner = queue.isDurable
        ? await syncService.authRepository.localUserId()
        : null;
    if (queue.isDurable && owner == null) return 0;
    var queued = 0;
    for (final target in targets) {
      var event = LearningEvent.telemetry(
        type: target.$1,
        targetId: target.$2,
        courseId: courseId,
        sessionId: sessionId,
        sequence: ++_sequence,
      );
      if (owner != null) {
        event = event.forLocalOwner(userId: owner, apiUrl: syncService.apiUrl);
      }
      if (await queue.enqueue(event)) queued++;
    }
    if (queued > 0) unawaited(syncService.flush());
    return queued;
  }
}
