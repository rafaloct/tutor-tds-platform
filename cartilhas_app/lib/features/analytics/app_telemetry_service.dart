import 'dart:async';

import '../../config/app_config.dart';
import '../../services/privacy_preferences.dart';
import '../learning_events/learning_event.dart';
import '../learning_events/learning_event_queue.dart';
import '../learning_events/learning_event_sync_service.dart';
import 'screen_engagement_clock.dart';

typedef TelemetryConsentChecker = Future<bool> Function();

class AppTelemetryService {
  AppTelemetryService({
    required this.syncService,
    this.queue = const LearningEventQueue(),
    this.consentChecker = PrivacyPreferences.hasConsent,
    String? sessionId,
    this.journeyEnabled = AppConfig.journeyTraceabilityEnabled,
    Duration Function()? elapsed,
  }) : sessionId = sessionId ?? LearningEvent.newSessionId(),
       screenClock = ScreenEngagementClock(elapsed ?? _elapsedClock());

  static Duration Function() _elapsedClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  static const applicationCourseId = '_app';

  final LearningEventSyncService syncService;
  final LearningEventQueue queue;
  final TelemetryConsentChecker consentChecker;
  final String sessionId;
  final bool journeyEnabled;
  final ScreenEngagementClock screenClock;
  int _sequence = 0;
  int _screenRevision = 0;
  String? _pageId, _screenOwner;
  String _screenCourse = applicationCourseId;
  int? _screenGeneration;

  Future<void> screenShown({
    String? pageId,
    String courseId = applicationCourseId,
  }) async {
    if (!journeyEnabled || !syncService.authRepository.isConfigured) return;
    final previous = checkpointScreen();
    final revision = ++_screenRevision;
    _pageId = pageId;
    _screenCourse = courseId;
    _screenOwner = null;
    screenClock.stop();
    final auth = syncService.authRepository;
    final generation = auth.sessionGeneration;
    final owner = await auth.localUserId();
    final consent = await consentChecker();
    final currentOwner = await auth.localUserId();
    if (revision == _screenRevision &&
        generation == auth.sessionGeneration &&
        pageId != null &&
        owner != null &&
        consent &&
        owner == currentOwner) {
      _screenOwner = owner;
      _screenGeneration = generation;
      screenClock.start();
    }
    await previous;
  }

  Future<int> checkpointScreen() async {
    if (!journeyEnabled) return 0;
    final seconds = screenClock.checkpoint();
    final page = _pageId, owner = _screenOwner;
    final generation = _screenGeneration;
    final course = _screenCourse;
    final auth = syncService.authRepository;
    if (generation != auth.sessionGeneration || owner == null) {
      screenClock.stop();
      return 0;
    }
    if (seconds == 0 || page == null) return 0;
    final revision = _screenRevision;
    if (!await consentChecker()) {
      if (revision == _screenRevision) {
        screenClock.stop();
        _screenOwner = null;
      }
      return 0;
    }
    if (generation != auth.sessionGeneration ||
        owner != await auth.localUserId()) {
      return 0;
    }
    final event = LearningEvent.telemetry(
      type: LearningEventType.screenEngagement,
      targetId: page,
      courseId: course,
      sessionId: sessionId,
      sequence: ++_sequence,
      activeSeconds: seconds,
    ).forLocalOwner(userId: owner, apiUrl: syncService.apiUrl);
    if (generation != auth.sessionGeneration) return 0;
    if (!await queue.enqueue(event)) return 0;
    unawaited(syncService.flush());
    return 1;
  }

  Future<void> heartbeatScreen() async {
    if (!journeyEnabled) return;
    if (_screenOwner == null ||
        _screenGeneration != syncService.authRepository.sessionGeneration) {
      await screenShown(pageId: _pageId, courseId: _screenCourse);
    } else {
      await checkpointScreen();
    }
  }

  void touch() {
    if (!journeyEnabled) return;
    unawaited(checkpointScreen());
    screenClock.touch();
    if (_screenGeneration != syncService.authRepository.sessionGeneration) {
      unawaited(heartbeatScreen());
    }
  }

  void setForeground(bool value) {
    if (!journeyEnabled) return;
    unawaited(checkpointScreen());
    screenClock.setForeground(value);
  }

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
    final generation = syncService.authRepository.sessionGeneration;
    final needsOwner = queue.isDurable || journeyEnabled;
    final owner = needsOwner
        ? await syncService.authRepository.localUserId()
        : null;
    if (!await consentChecker() ||
        generation != syncService.authRepository.sessionGeneration) {
      return 0;
    }
    if (needsOwner &&
        (owner == null ||
            owner != await syncService.authRepository.localUserId())) {
      return 0;
    }
    var queued = 0;
    for (final target in targets) {
      if (generation != syncService.authRepository.sessionGeneration) break;
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
