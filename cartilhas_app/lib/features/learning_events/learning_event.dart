import 'dart:convert';
import 'dart:math';

enum LearningEventType { lessonStarted, lessonCompleted, studyActivity }

extension LearningEventTypeValue on LearningEventType {
  String get apiValue => switch (this) {
    LearningEventType.lessonStarted => 'lesson_started',
    LearningEventType.lessonCompleted => 'lesson_completed',
    LearningEventType.studyActivity => 'study_activity',
  };
}

class LearningEvent {
  const LearningEvent({
    required this.eventId,
    required this.type,
    required this.courseId,
    required this.sessionId,
    required this.occurredAt,
    this.activeSeconds,
  });

  final String eventId;
  final LearningEventType type;
  final String courseId;
  final String sessionId;
  final DateTime occurredAt;
  final int? activeSeconds;

  factory LearningEvent.forSession({
    required LearningEventType type,
    required String courseId,
    required String sessionId,
    DateTime? occurredAt,
  }) {
    if (type == LearningEventType.studyActivity) {
      throw ArgumentError.value(type, 'type', 'Use LearningEvent.activity.');
    }
    return LearningEvent(
      eventId: '$sessionId:${type.apiValue}',
      type: type,
      courseId: courseId,
      sessionId: sessionId,
      occurredAt: occurredAt ?? DateTime.now(),
    );
  }

  factory LearningEvent.activity({
    required String courseId,
    required String sessionId,
    required int sequence,
    required int activeSeconds,
    DateTime? occurredAt,
  }) {
    if (sequence < 1) {
      throw ArgumentError.value(sequence, 'sequence', 'Deve ser positivo.');
    }
    if (activeSeconds < 1 || activeSeconds > 60) {
      throw ArgumentError.value(
        activeSeconds,
        'activeSeconds',
        'Deve estar entre 1 e 60.',
      );
    }
    return LearningEvent(
      eventId:
          '$sessionId:${LearningEventType.studyActivity.apiValue}:$sequence',
      type: LearningEventType.studyActivity,
      courseId: courseId,
      sessionId: sessionId,
      occurredAt: occurredAt ?? DateTime.now(),
      activeSeconds: activeSeconds,
    );
  }

  static String newSessionId({DateTime? now, Random? random}) {
    final timestamp = (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
    final source = random ?? Random.secure();
    final bytes = List<int>.generate(12, (_) => source.nextInt(256));
    final suffix = base64UrlEncode(bytes).replaceAll('=', '');
    return '$timestamp-$suffix';
  }

  Map<String, Object> toJson() => {
    'event_id': eventId,
    'event_type': type.apiValue,
    'course_id': courseId,
    'session_id': sessionId,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'active_seconds': ?activeSeconds,
  };

  static LearningEvent? fromJson(Object? source) {
    if (source is! Map<String, dynamic>) return null;
    final eventId = source['event_id'];
    final courseId = source['course_id'];
    final sessionId = source['session_id'];
    final occurredAt = DateTime.tryParse(
      source['occurred_at'] as String? ?? '',
    );
    final typeValue = source['event_type'];
    final activeSeconds = source['active_seconds'];
    LearningEventType? type;
    for (final candidate in LearningEventType.values) {
      if (candidate.apiValue == typeValue) type = candidate;
    }
    if (eventId is! String ||
        eventId.isEmpty ||
        courseId is! String ||
        courseId.isEmpty ||
        sessionId is! String ||
        sessionId.isEmpty ||
        occurredAt == null ||
        type == null ||
        (type == LearningEventType.studyActivity &&
            (activeSeconds is! int ||
                activeSeconds < 1 ||
                activeSeconds > 60)) ||
        (type != LearningEventType.studyActivity && activeSeconds != null)) {
      return null;
    }
    return LearningEvent(
      eventId: eventId,
      type: type,
      courseId: courseId,
      sessionId: sessionId,
      occurredAt: occurredAt,
      activeSeconds: activeSeconds as int?,
    );
  }
}
