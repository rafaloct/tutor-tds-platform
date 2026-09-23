import 'learning_event.dart';

/// Read/delivery scope supplied by a resolved LearningContext, never authority.
class LearningDeliveryScope {
  LearningDeliveryScope({
    required this.ownerId,
    required String apiUrl,
    required this.cohortId,
    required this.courseVersionId,
    required this.courseId,
  }) : apiUrl = apiUrl.replaceFirst(RegExp(r'/+$'), '') {
    if ([
      ownerId,
      this.apiUrl,
      cohortId,
      courseVersionId,
      courseId,
    ].any((value) => value.isEmpty)) {
      throw ArgumentError('A complete learning delivery scope is required');
    }
  }

  final String ownerId;
  final String apiUrl;
  final String cohortId;
  final String courseVersionId;
  final String courseId;

  bool matches(LearningEvent event) =>
      event.localOwnerId == ownerId &&
      event.localApiUrl == apiUrl &&
      event.courseId == courseId &&
      event.payload['class_id'] == cohortId &&
      event.payload['course_version_id'] == courseVersionId &&
      const {
        LearningEventType.lessonStarted,
        LearningEventType.lessonCompleted,
        LearningEventType.studyActivity,
      }.contains(event.type);

  @override
  bool operator ==(Object other) =>
      other is LearningDeliveryScope &&
      ownerId == other.ownerId &&
      apiUrl == other.apiUrl &&
      cohortId == other.cohortId &&
      courseVersionId == other.courseVersionId &&
      courseId == other.courseId;

  @override
  int get hashCode =>
      Object.hash(ownerId, apiUrl, cohortId, courseVersionId, courseId);
}

class BlockedLearningEvent {
  const BlockedLearningEvent({
    required this.eventId,
    this.lastStatus,
    this.nextAttemptAt,
  });
  final String eventId;
  final int? lastStatus;
  final DateTime? nextAttemptAt;
}

class LearningDeliverySnapshot {
  const LearningDeliverySnapshot({
    this.pendingCount = 0,
    this.retryCount = 0,
    this.blockedCount = 0,
    this.nextAttemptAt,
    this.blockedEvents = const [],
    this.requiresAccessRefresh = false,
  });
  final int pendingCount;
  final int retryCount;
  final int blockedCount;
  final DateTime? nextAttemptAt;
  final List<BlockedLearningEvent> blockedEvents;
  final bool requiresAccessRefresh;
  bool get isEmpty => pendingCount + retryCount + blockedCount == 0;
}

/// Durable delivery contract. Event IDs and payloads never change on retry.
abstract interface class LearningOutbox {
  Future<void> importLegacy(String source);
  Future<bool> enqueue(LearningEvent event);
  Future<List<LearningEvent>> pending({DateTime? readyAt});
  Future<bool> acknowledge(String eventId);
  Future<void> fail(String eventId, {required DateTime now, int? statusCode});
  Future<LearningDeliverySnapshot> deliveryStatus(LearningDeliveryScope scope);
  Future<bool> retryBlocked(
    String eventId, {
    required LearningDeliveryScope scope,
  });
  Future<void> clear({required bool preserveOwned});
}

/// Known platform/storage availability failures; never a successful empty read.
class OutboxStorageException implements Exception {
  const OutboxStorageException(this.operation, {this.sqliteCode});
  final String operation;
  final int? sqliteCode;
  @override
  String toString() => 'OutboxStorageException: $operation ($sqliteCode)';
}

/// Evidence or database content cannot be decoded. Do not erase or skip it.
class OutboxDataException extends FormatException {
  const OutboxDataException(String boundary)
    : super('Invalid outbox data', boundary);
  @override
  String toString() => 'OutboxDataException: $source';
}

/// Legacy cleanup failed after a durable import; source and receipts remain.
class OutboxMigrationException implements Exception {
  const OutboxMigrationException({required this.committed});
  final bool committed;
  @override
  String toString() => 'OutboxMigrationException: committed=$committed';
}

class OutboxConflict implements Exception {
  const OutboxConflict(this.eventId);
  final String eventId;
  @override
  String toString() => 'OutboxConflict: immutable event_id $eventId';
}
