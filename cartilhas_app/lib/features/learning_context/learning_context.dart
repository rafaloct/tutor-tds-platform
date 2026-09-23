import 'dart:convert';

import '../../models/cartilha.dart';

/// A server-resolved read model. Permissions are never inferred from UI roles.
class LearningContext {
  const LearningContext({
    required this.userId,
    required this.organizationId,
    required this.programId,
    required this.cohortId,
    required this.membershipId,
    required this.role,
    required this.courseId,
    required this.courseVersionId,
    required this.enrollmentId,
    this.legacyEnrollmentId,
    required this.permissions,
  });

  final String userId, organizationId, programId, cohortId, membershipId, role;
  final String courseId, courseVersionId, enrollmentId;
  // Explicit server-provided lineage. Null only for cached v1 snapshots.
  final String? legacyEnrollmentId;
  final Set<String> permissions;

  factory LearningContext.fromJson(Map<String, dynamic> json) {
    String field(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing learning context field: $key');
      }
      return value;
    }

    final rawPermissions = json['permissions'];
    if (rawPermissions is! List ||
        rawPermissions.any((item) => item is! String)) {
      throw const FormatException('Invalid permissions');
    }
    return LearningContext(
      userId: field('user_id'),
      organizationId: field('organization_id'),
      programId: field('program_id'),
      cohortId: field('cohort_id'),
      membershipId: field('membership_id'),
      role: field('role'),
      courseId: field('course_id'),
      courseVersionId: field('course_version_id'),
      enrollmentId: field('enrollment_id'),
      legacyEnrollmentId: json.containsKey('legacy_enrollment_id')
          ? field('legacy_enrollment_id')
          : null,
      permissions: Set.unmodifiable(rawPermissions.cast<String>()),
    );
  }

  bool matchesCourse(Cartilha course) =>
      course.id == courseId &&
      course.classId == cohortId &&
      course.courseVersionId == courseVersionId;

  /// Stable local reading position across v1 -> v2. The full cohort, owner,
  /// membership and immutable edition scope prevents sharing parallel progress.
  String resumeKey(String apiUrl) => jsonEncode([
    apiUrl.replaceFirst(RegExp(r'/+$'), ''),
    userId,
    cohortId,
    membershipId,
    legacyEnrollmentId ?? enrollmentId,
    courseVersionId,
  ]);

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'organization_id': organizationId,
    'program_id': programId,
    'cohort_id': cohortId,
    'membership_id': membershipId,
    'role': role,
    'course_id': courseId,
    'course_version_id': courseVersionId,
    'enrollment_id': enrollmentId,
    if (legacyEnrollmentId != null) 'legacy_enrollment_id': legacyEnrollmentId,
    'permissions': permissions.toList(),
  };
}

class LearningContextSnapshot {
  const LearningContextSnapshot({
    required this.context,
    required this.progressPercent,
    required this.validatedHours,
    required this.resolvedAt,
    required this.contractVersion,
    this.fromCache = false,
  });
  final LearningContext context;
  final double progressPercent, validatedHours;
  final DateTime resolvedAt;
  final String contractVersion;
  final bool fromCache;

  Map<String, dynamic> toCacheJson() => {
    'context': context.toJson(),
    'progress': {
      'user_id': context.userId,
      'enrollment_id': context.legacyEnrollmentId ?? context.enrollmentId,
      if (contractVersion == 'cohort-enrollment-v2')
        'context_enrollment_id': context.enrollmentId,
      'progress_percent': progressPercent,
      'validated_hours': validatedHours,
    },
    'resolved_at': resolvedAt.toUtc().toIso8601String(),
    'contract_version': contractVersion,
  };

  factory LearningContextSnapshot.fromJson(
    Map<String, dynamic> json, {
    bool fromCache = false,
  }) {
    final context = LearningContext.fromJson(
      Map<String, dynamic>.from(json['context'] as Map),
    );
    final progress = json['progress'] as Map;
    final percent = (progress['progress_percent'] as num).toDouble();
    final hours = (progress['validated_hours'] as num).toDouble();
    final resolved = DateTime.parse(json['resolved_at'] as String);
    final version = json['contract_version'];
    final validLineage = switch (version) {
      'legacy-lineage-v1' =>
        context.legacyEnrollmentId == null &&
            progress['enrollment_id'] == context.enrollmentId,
      'cohort-enrollment-v2' =>
        context.legacyEnrollmentId != null &&
            context.legacyEnrollmentId != context.enrollmentId &&
            progress['enrollment_id'] == context.legacyEnrollmentId &&
            progress['context_enrollment_id'] == context.enrollmentId,
      _ => false,
    };
    if (progress['user_id'] != context.userId ||
        !validLineage ||
        !percent.isFinite ||
        percent < 0 ||
        percent > 100 ||
        !hours.isFinite ||
        hours < 0 ||
        context.role != 'student') {
      throw const FormatException('Inconsistent learning context snapshot');
    }
    return LearningContextSnapshot(
      context: context,
      progressPercent: percent,
      validatedHours: hours,
      resolvedAt: resolved,
      contractVersion: json['contract_version'] as String,
      fromCache: fromCache,
    );
  }
}
