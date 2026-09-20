import 'learning_event.dart';

class LearningActivityTracker {
  LearningActivityTracker({
    required this.courseId,
    required this.sessionId,
    this.maxActiveSeconds = 60,
    this.maxGapSeconds = 90,
  });

  final String courseId;
  final String sessionId;
  final int maxActiveSeconds;
  final int maxGapSeconds;
  DateTime? _lastInteractionAt;
  var _sequence = 0;

  LearningEvent? recordInteraction({DateTime? now}) {
    final occurredAt = now ?? DateTime.now();
    final previous = _lastInteractionAt;
    if (previous == null) {
      _lastInteractionAt = occurredAt;
      return null;
    }
    final elapsed = occurredAt.difference(previous).inSeconds;
    if (elapsed < 1) return null;

    _lastInteractionAt = occurredAt;
    if (elapsed > maxGapSeconds) return null;
    _sequence++;
    return LearningEvent.activity(
      courseId: courseId,
      sessionId: sessionId,
      sequence: _sequence,
      activeSeconds: elapsed.clamp(1, maxActiveSeconds),
      occurredAt: occurredAt,
    );
  }

  void reset() => _lastInteractionAt = null;
}
