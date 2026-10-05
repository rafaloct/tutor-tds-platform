class ClassLifecycleCapabilities {
  const ClassLifecycleCapabilities({
    required this.canPrepare,
    required this.canClose,
    required this.canActivate,
    required this.canOverrideCapacity,
    this.prepareDeniedMessage,
    this.closeDeniedMessage,
  });

  final bool canPrepare;
  final bool canClose;
  final bool canActivate;
  final bool canOverrideCapacity;
  final String? prepareDeniedMessage;
  final String? closeDeniedMessage;

  bool get hasManagementSurface => canPrepare || canClose;
}

class LifecycleProgram {
  const LifecycleProgram({
    required this.id,
    required this.institutionId,
    required this.name,
  });

  final String id;
  final String institutionId;
  final String name;
}

class LifecycleCourse {
  const LifecycleCourse({
    required this.id,
    required this.programId,
    required this.name,
  });

  final String id;
  final String programId;
  final String name;
}

class PublishedCourseVersionInfo {
  const PublishedCourseVersionInfo({
    required this.opaqueId,
    required this.label,
  });

  final String opaqueId;
  final String label;
}

class LifecycleStaffMember {
  const LifecycleStaffMember({
    required this.id,
    required this.name,
    required this.kind,
  });

  final String id;
  final String name;
  final LifecycleStaffKind kind;
}

enum LifecycleStaffKind { teacher, monitor }

class LifecycleClassSummary {
  const LifecycleClassSummary({
    required this.id,
    required this.name,
    required this.statusLabel,
  });

  final String id;
  final String name;
  final String statusLabel;
}

class ClassLifecycleBootstrap {
  const ClassLifecycleBootstrap({
    required this.capabilities,
    required this.programs,
    required this.manageableClasses,
  });

  final ClassLifecycleCapabilities capabilities;
  final List<LifecycleProgram> programs;
  final List<LifecycleClassSummary> manageableClasses;
}

class ClassCapacitySnapshot {
  const ClassCapacitySnapshot({
    required this.occupancy,
    required this.capacity,
    required this.canProceed,
    required this.requiresOverrideReason,
    required this.message,
    this.deferredToParticipants = false,
  });

  final int occupancy;
  final int capacity;
  final bool canProceed;
  final bool requiresOverrideReason;
  final String message;
  final bool deferredToParticipants;
}

class PrepareClassroomCommand {
  const PrepareClassroomCommand({
    required this.className,
    required this.offerMunicipality,
    required this.offerLocation,
    required this.institutionId,
    required this.programId,
    required this.courseId,
    required this.courseVersionId,
    required this.startDate,
    required this.endDate,
    required this.teacherId,
    required this.monitorIds,
    this.capacityOverrideReason,
  });

  final String className;
  final String offerMunicipality;
  final String offerLocation;
  final String institutionId;
  final String programId;
  final String courseId;
  final String courseVersionId;
  final DateTime startDate;
  final DateTime endDate;
  final String teacherId;
  final List<String> monitorIds;
  final String? capacityOverrideReason;
}

class PreparedClassroomResult {
  const PreparedClassroomResult({
    required this.opaqueId,
    required this.name,
    required this.statusLabel,
  });

  final String opaqueId;
  final String name;
  final String statusLabel;
}

class ClassCloseReadiness {
  const ClassCloseReadiness({
    required this.classroomId,
    required this.classroomName,
    required this.openSessions,
    required this.pendingAttendance,
    required this.pendingEvidence,
    required this.participants,
    required this.pendingCertificateRequests,
    required this.canClose,
    required this.blockers,
  });

  final String classroomId;
  final String classroomName;
  final int openSessions;
  final int pendingAttendance;
  final int pendingEvidence;
  final int participants;
  final int pendingCertificateRequests;
  final bool canClose;
  final List<String> blockers;
}

class ClosedClassroomResult {
  const ClosedClassroomResult({
    required this.classroomId,
    required this.statusLabel,
  });

  final String classroomId;
  final String statusLabel;
}
