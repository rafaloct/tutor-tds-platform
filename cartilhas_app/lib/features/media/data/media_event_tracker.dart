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

  Future<void> started() async {
    if (_started) return;
    _started = true;
    await _enqueue(LearningEventType.videoStarted);
  }

  Future<void> progress({
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    if (durationSeconds <= 0 || positionSeconds < 0) return;
    await started();
    final fraction = positionSeconds / durationSeconds;
    for (final checkpoint in const [25, 50, 75]) {
      if (fraction >= checkpoint / 100 && _checkpoints.add(checkpoint)) {
        await _enqueue(
          LearningEventType.videoCheckpoint,
          checkpoint: checkpoint,
          positionSeconds: positionSeconds,
        );
      }
    }
    if (fraction >= 0.9) await completed(positionSeconds: positionSeconds);
  }

  Future<void> completed({required int positionSeconds}) async {
    if (_completed) return;
    _completed = true;
    await _enqueue(
      LearningEventType.videoCompleted,
      positionSeconds: positionSeconds,
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
    );
    final owner = await _owner;
    if (owner != null) {
      event = event.forLocalOwner(userId: owner, apiUrl: syncService.apiUrl);
    }
    await queue.enqueue(event);
    unawaited(syncService.flush());
  }
}
