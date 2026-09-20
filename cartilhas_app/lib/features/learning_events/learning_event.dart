import 'dart:convert';
import 'dart:math';

enum LearningEventType {
  lessonStarted,
  lessonCompleted,
  studyActivity,
  pageViewed,
  resourceOpened,
  featureUsed,
}

extension LearningEventTypeValue on LearningEventType {
  String get apiValue => switch (this) {
    LearningEventType.lessonStarted => 'lesson_started',
    LearningEventType.lessonCompleted => 'lesson_completed',
    LearningEventType.studyActivity => 'study_activity',
    LearningEventType.pageViewed => 'page_viewed',
    LearningEventType.resourceOpened => 'resource_opened',
    LearningEventType.featureUsed => 'feature_used',
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
    this.payload = const {},
  });

  final String eventId;
  final LearningEventType type;
  final String courseId;
  final String sessionId;
  final DateTime occurredAt;
  final int? activeSeconds;
  final Map<String, String> payload;

  bool get isTelemetry =>
      type == LearningEventType.pageViewed ||
      type == LearningEventType.resourceOpened ||
      type == LearningEventType.featureUsed;

  factory LearningEvent.forSession({
    required LearningEventType type,
    required String courseId,
    required String sessionId,
    DateTime? occurredAt,
  }) {
    if (type != LearningEventType.lessonStarted &&
        type != LearningEventType.lessonCompleted) {
      throw ArgumentError.value(type, 'type', 'Tipo de sessão inválido.');
    }
    return LearningEvent(
      eventId: '$sessionId:${type.apiValue}',
      type: type,
      courseId: courseId,
      sessionId: sessionId,
      occurredAt: occurredAt ?? DateTime.now(),
    );
  }

  factory LearningEvent.telemetry({
    required LearningEventType type,
    required String targetId,
    required String courseId,
    required String sessionId,
    required int sequence,
    DateTime? occurredAt,
  }) {
    final payloadKey = switch (type) {
      LearningEventType.pageViewed => 'page_id',
      LearningEventType.resourceOpened => 'resource_id',
      LearningEventType.featureUsed => 'feature_id',
      _ => throw ArgumentError.value(
        type,
        'type',
        'Tipo de telemetria inválido.',
      ),
    };
    if (sequence < 1) {
      throw ArgumentError.value(sequence, 'sequence', 'Deve ser positivo.');
    }
    if (!_isStableIdentifier(targetId)) {
      throw ArgumentError.value(
        targetId,
        'targetId',
        'Identificador inválido.',
      );
    }
    return LearningEvent(
      eventId: '$sessionId:${type.apiValue}:$sequence',
      type: type,
      courseId: courseId,
      sessionId: sessionId,
      occurredAt: occurredAt ?? DateTime.now(),
      payload: {payloadKey: targetId},
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
    if (payload.isNotEmpty) 'payload': payload,
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
    final rawPayload = source['payload'];
    if (rawPayload != null &&
        (rawPayload is! Map ||
            rawPayload.keys.any((key) => key is! String) ||
            rawPayload.values.any((value) => value is! String))) {
      return null;
    }
    final payload = rawPayload is Map
        ? Map<String, String>.from(rawPayload)
        : <String, String>{};
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
        (type != LearningEventType.studyActivity && activeSeconds != null) ||
        !_validPayload(type, payload)) {
      return null;
    }
    return LearningEvent(
      eventId: eventId,
      type: type,
      courseId: courseId,
      sessionId: sessionId,
      occurredAt: occurredAt,
      activeSeconds: activeSeconds as int?,
      payload: Map.unmodifiable(payload),
    );
  }

  static bool _validPayload(
    LearningEventType type,
    Map<String, String> payload,
  ) {
    final expectedKey = switch (type) {
      LearningEventType.pageViewed => 'page_id',
      LearningEventType.resourceOpened => 'resource_id',
      LearningEventType.featureUsed => 'feature_id',
      _ => null,
    };
    if (expectedKey == null) return payload.isEmpty;
    return payload.length == 1 &&
        payload.containsKey(expectedKey) &&
        _isStableIdentifier(payload[expectedKey]!);
  }

  static bool _isStableIdentifier(String value) =>
      RegExp(r'^[a-z0-9][a-z0-9_.-]{0,79}$').hasMatch(value);
}
