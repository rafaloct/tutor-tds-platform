/// Presentation contracts. IDs always originate from the authorized gateway.
/// These are projections of existing TDS entities, not another participant store.
class OperationScope {
  const OperationScope({
    required this.institutionId,
    required this.programId,
    required this.courseId,
    required this.classId,
    required this.versionId,
    required this.label,
  });
  final String institutionId, programId, courseId, classId, versionId, label;
}

class OperationPerson {
  const OperationPerson(this.id, this.name);
  final String id, name;
}

class OperationHistory {
  const OperationHistory({
    required this.action,
    required this.reason,
    required this.actorLabel,
    required this.occurredAt,
  });
  final String action, reason, actorLabel;
  final DateTime occurredAt;
}

class OperationSnapshot {
  OperationSnapshot({
    required this.person,
    required this.scope,
    required this.revision,
    required this.enrolled,
    required this.assigned,
    required this.baselineLinked,
    required List<OperationHistory> history,
  }) : history = List.unmodifiable(history);
  final OperationPerson person;
  final OperationScope scope;
  final int revision;
  final bool enrolled, assigned;
  final bool? baselineLinked;
  final List<OperationHistory> history;
}

/// Kept only in memory while a command is pending. Never log/serialize by UI.
/// A production adapter must use the existing account identity contract.
class OperationRegistration {
  const OperationRegistration({
    required this.name,
    required this.cpf,
    required this.phone,
    required this.password,
  });
  final String name, cpf, phone, password;
}

enum OperationAction { register, enroll, assign, revoke }

class OperationCommand {
  const OperationCommand({
    required this.id,
    required this.sessionKey,
    required this.scope,
    required this.action,
    required this.reason,
    this.personId,
    this.expectedRevision,
    this.registration,
  });
  final String id, sessionKey, reason;
  final OperationScope scope;
  final OperationAction action;
  final String? personId;
  final int? expectedRevision;
  final OperationRegistration? registration;
}

enum OperationFailureKind { unavailable, denied, conflict, invalid }

class OperationFailure implements Exception {
  const OperationFailure(this.kind);
  final OperationFailureKind kind;
}
