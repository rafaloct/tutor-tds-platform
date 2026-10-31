import 'dart:async';

import '../../learning_events/learning_event.dart';
import '../../learning_events/learning_event_queue.dart';
import '../../learning_events/learning_event_sync_service.dart';
import '../models/media_models.dart';

class MediaEventTracker {
  MediaEventTracker({
    required this.media,
    required this.syncService,
    this.queue = const LearningEventQueue(),
    String? sessionId,
  }) : sessionId = sessionId ?? LearningEvent.newSessionId(),
       _owner = queue.isDurable
           ? syncService.authRepository.localUserId()
           : Future.value(null);

  final MediaItem media;
  final LearningEventSyncService syncService;
  final LearningEventQueue queue;
  final String sessionId;
  final Future<String?> _owner;
  final Set<int> _checkpoints = {};
  bool _started = false;
  bool _completed = false;
  int _lastCheckpointPosition = 0;
  DateTime? _lastOccurredAt;

  DateTime _nextOccurredAt() {
    final now = DateTime.now().toUtc();
    final baseline = now.subtract(const Duration(milliseconds: 200));
    final prev = _lastOccurredAt;
    final next = prev == null
        ? baseline
        : prev.add(const Duration(milliseconds: 20));
    _lastOccurredAt = next.isAfter(now) ? now : next;
    return _lastOccurredAt!;
  }

  Future<void> started() async {
    if (_started) return;
    _started = true;
    await _enqueue(LearningEventType.videoStarted);
  }

  Future<void> progress({
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    final effectiveDuration = durationSeconds > 0
        ? durationSeconds
        : media.durationSeconds;
    if (effectiveDuration <= 0 || positionSeconds < 0) return;
    await started();
    final clampedPos = positionSeconds.clamp(0, effectiveDuration);
    final fraction = clampedPos / effectiveDuration;
    for (final checkpoint in const [25, 50, 75]) {
      if (fraction >= checkpoint / 100 && _checkpoints.add(checkpoint)) {
        final targetPos = ((effectiveDuration * checkpoint) / 100).ceil();
        var cpPos = targetPos < clampedPos ? targetPos : clampedPos;
        if (cpPos <= _lastCheckpointPosition) {
          cpPos = _lastCheckpointPosition + 1;
        }
        _lastCheckpointPosition = cpPos;
        await _enqueue(
          LearningEventType.videoCheckpoint,
          checkpoint: checkpoint,
          positionSeconds: cpPos,
        );
      }
    }
    if (fraction >= 0.9) {
      await completed(
        positionSeconds: clampedPos,
        durationSeconds: effectiveDuration,
      );
    }
  }

  Future<void> completed({
    required int positionSeconds,
    int? durationSeconds,
  }) async {
    if (_completed) return;
    final effectiveDuration = (durationSeconds != null && durationSeconds > 0)
        ? durationSeconds
        : media.durationSeconds;
    if (effectiveDuration > 0) {
      await started();
      for (final checkpoint in const [25, 50, 75]) {
        if (_checkpoints.add(checkpoint)) {
          var cpPos = ((effectiveDuration * checkpoint) / 100).ceil();
          if (cpPos <= _lastCheckpointPosition) {
            cpPos = _lastCheckpointPosition + 1;
          }
          _lastCheckpointPosition = cpPos;
          await _enqueue(
            LearningEventType.videoCheckpoint,
            checkpoint: checkpoint,
            positionSeconds: cpPos,
          );
        }
      }
    }
    _completed = true;
    final minCompleted = effectiveDuration > 0
        ? (effectiveDuration * 0.9).ceil()
        : positionSeconds;
    var finalPos = positionSeconds < minCompleted
        ? minCompleted
        : (effectiveDuration > 0 && positionSeconds > effectiveDuration
              ? effectiveDuration
              : positionSeconds);
    if (finalPos <= _lastCheckpointPosition && effectiveDuration > 0) {
      finalPos = (_lastCheckpointPosition + 1).clamp(0, effectiveDuration + 5);
    }
    await _enqueue(
      LearningEventType.videoCompleted,
      positionSeconds: finalPos,
      waitForFlush: true,
    );
  }

  Future<void> saved() => _enqueue(LearningEventType.videoSaved);

  Future<void> followupCompleted(String type) =>
      _enqueue(LearningEventType.videoFollowupCompleted, followupType: type);

  Future<void> _enqueue(
    LearningEventType type, {
    int? checkpoint,
    int? positionSeconds,
    String? followupType,
    bool waitForFlush = false,
  }) async {
    var event = LearningEvent.video(
      type: type,
      mediaId: media.id,
      moduleId: media.moduleId,
      courseId: media.courseId,
      sessionId: sessionId,
      checkpoint: checkpoint,
      positionSeconds: positionSeconds,
      followupType: followupType,
      occurredAt: _nextOccurredAt(),
    );
    final owner = await _owner;
    if (owner != null) {
      event = event.forLocalOwner(userId: owner, apiUrl: syncService.apiUrl);
    }
    await queue.enqueue(event);
    if (waitForFlush) {
      await syncService.flush();
    } else {
      unawaited(syncService.flush());
    }
  }
}
