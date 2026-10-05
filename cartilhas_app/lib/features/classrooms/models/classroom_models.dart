class EligibleStudent {
  const EligibleStudent({required this.userId, required this.name});
  final String userId;
  final String name;

  factory EligibleStudent.fromJson(Map<String, dynamic> json) =>
      EligibleStudent(
        userId: _requiredString(json, 'user_id'),
        name: _requiredString(json, 'name'),
      );
}

class EligibleStudentPage {
  const EligibleStudentPage({required this.students, this.nextOffset});
  final List<EligibleStudent> students;
  final int? nextOffset;

  factory EligibleStudentPage.fromJson(Map<String, dynamic> json) {
    final students = json['students'];
    if (students is! List<dynamic> ||
        students.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('Lista de estudantes inválida.');
    }
    return EligibleStudentPage(
      students: students
          .cast<Map<String, dynamic>>()
          .map(EligibleStudent.fromJson)
          .toList(growable: false),
      nextOffset: _nullableInt(json['next_offset']),
    );
  }
}

class ClassroomDetails {
  const ClassroomDetails({
    required this.id,
    required this.programId,
    required this.courseId,
    required this.teacherId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.studentIds,
    required this.monitorIds,
    this.courseVersionId,
  });

  final String id;
  final String programId;
  final String courseId;
  final String teacherId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final List<String> studentIds;
  final List<String> monitorIds;
  final String? courseVersionId;

  factory ClassroomDetails.fromJson(Map<String, dynamic> json) {
    return ClassroomDetails(
      id: _requiredString(json, 'id'),
      programId: _requiredString(json, 'program_id'),
      courseId: _requiredString(json, 'course_id'),
      teacherId: _requiredString(json, 'teacher_id'),
      name: _requiredString(json, 'name'),
      startDate: _requiredDate(json, 'start_date'),
      endDate: _requiredDate(json, 'end_date'),
      status: _requiredString(json, 'status'),
      studentIds: _stringList(json, 'student_ids'),
      monitorIds: _stringList(json, 'monitor_ids'),
      courseVersionId: json['course_version_id'] as String?,
    );
  }
}

class ClassroomAlert {
  const ClassroomAlert({required this.code});
  final String code;

  factory ClassroomAlert.fromJson(Map<String, dynamic> json) =>
      ClassroomAlert(code: _requiredString(json, 'code'));
}

class MonitorExceptionStudent {
  const MonitorExceptionStudent({
    required this.userId,
    required this.name,
    required this.alerts,
  });

  final String userId;
  final String name;
  final List<ClassroomAlert> alerts;

  factory MonitorExceptionStudent.fromJson(Map<String, dynamic> json) {
    final rawAlerts = json['alerts'];
    if (rawAlerts is! List<dynamic> ||
        rawAlerts.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('Sinais do participante inválidos.');
    }
    return MonitorExceptionStudent(
      userId: _requiredString(json, 'user_id'),
      name: _requiredString(json, 'name'),
      alerts: rawAlerts
          .cast<Map<String, dynamic>>()
          .map(ClassroomAlert.fromJson)
          .toList(growable: false),
    );
  }
}

class MonitorExceptions {
  const MonitorExceptions({
    required this.generatedAt,
    required this.totalStudents,
    required this.attentionStudents,
    required this.students,
  });

  final DateTime generatedAt;
  final int totalStudents;
  final int attentionStudents;
  final List<MonitorExceptionStudent> students;

  int get normalStudents => totalStudents - attentionStudents;

  factory MonitorExceptions.fromJson(Map<String, dynamic> json) {
    final rawStudents = json['students'];
    if (rawStudents is! List<dynamic> ||
        rawStudents.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('Acompanhamento do monitor inválido.');
    }
    final students = rawStudents
        .cast<Map<String, dynamic>>()
        .map(MonitorExceptionStudent.fromJson)
        .toList(growable: false);
    final totalStudents = _requiredInt(json, 'total_students');
    final attentionStudents = _requiredInt(json, 'attention_students');
    if (totalStudents < 0 ||
        attentionStudents < 0 ||
        attentionStudents > totalStudents ||
        attentionStudents != students.length) {
      throw const FormatException('Resumo do acompanhamento inválido.');
    }
    return MonitorExceptions(
      generatedAt: _requiredDate(json, 'generated_at'),
      totalStudents: totalStudents,
      attentionStudents: attentionStudents,
      students: students,
    );
  }
}

class ClassroomStudent {
  const ClassroomStudent({
    required this.userId,
    required this.name,
    required this.enrollmentId,
    required this.status,
    required this.plannedHours,
    required this.validatedHours,
    required this.progressPercent,
    required this.lastActivityAt,
    required this.inactiveDays,
    required this.alerts,
    this.baselineLinked,
    this.confirmedSessions,
    this.openMentorshipCases,
  });

  final String userId;
  final String name;
  final String enrollmentId;
  final String status;
  final double plannedHours;
  final double validatedHours;
  final double progressPercent;
  final DateTime? lastActivityAt;
  final int? inactiveDays;
  final List<ClassroomAlert> alerts;
  final bool? baselineLinked;
  final int? confirmedSessions;
  final int? openMentorshipCases;

  double get completion => (progressPercent / 100).clamp(0, 1);

  factory ClassroomStudent.fromJson(Map<String, dynamic> json) {
    final rawAlerts = json['alerts'];
    if (rawAlerts is! List<dynamic>) {
      throw const FormatException('Alertas do participante inválidos.');
    }
    return ClassroomStudent(
      userId: _requiredString(json, 'user_id'),
      name: _requiredString(json, 'name'),
      enrollmentId: _requiredString(json, 'enrollment_id'),
      status: _requiredString(json, 'status'),
      plannedHours: _requiredNumber(json, 'planned_hours'),
      validatedHours: _requiredNumber(json, 'validated_hours'),
      progressPercent: _requiredNumber(json, 'progress_percent'),
      lastActivityAt: _nullableDate(json['last_activity_at']),
      inactiveDays: _nullableInt(json['inactive_days']),
      baselineLinked: json['baseline_linked'] as bool?,
      confirmedSessions: _nullableInt(json['confirmed_sessions']),
      openMentorshipCases: _nullableInt(json['open_mentorship_cases']),
      alerts: rawAlerts
          .whereType<Map<String, dynamic>>()
          .map(ClassroomAlert.fromJson)
          .toList(growable: false),
    );
  }
}

class ClassroomDashboardSummary {
  const ClassroomDashboardSummary({
    required this.totalStudents,
    required this.inactiveStudents,
    required this.pendingStudents,
    required this.belowExpectedStudents,
    this.baselineLinkedStudents,
    this.confirmedParticipations,
    this.openMentorshipCases,
  });

  final int totalStudents;
  final int inactiveStudents;
  final int pendingStudents;
  final int belowExpectedStudents;
  final int? baselineLinkedStudents;
  final int? confirmedParticipations;
  final int? openMentorshipCases;

  factory ClassroomDashboardSummary.fromJson(Map<String, dynamic> json) =>
      ClassroomDashboardSummary(
        totalStudents: _requiredInt(json, 'total_students'),
        inactiveStudents: _requiredInt(json, 'inactive_students'),
        pendingStudents: _requiredInt(json, 'pending_students'),
        belowExpectedStudents: _requiredInt(json, 'below_expected_students'),
        baselineLinkedStudents: _nullableInt(json['baseline_linked_students']),
        confirmedParticipations: _nullableInt(json['confirmed_participations']),
        openMentorshipCases: _nullableInt(json['open_mentorship_cases']),
      );
}

class ClassroomDashboard {
  const ClassroomDashboard({
    required this.classroom,
    required this.generatedAt,
    required this.expectedProgressPercent,
    required this.summary,
    required this.students,
  });

  final ClassroomDetails classroom;
  final DateTime generatedAt;
  final double expectedProgressPercent;
  final ClassroomDashboardSummary summary;
  final List<ClassroomStudent> students;

  factory ClassroomDashboard.fromJson(Map<String, dynamic> json) {
    final rawClassroom = json['classroom'];
    final rawSummary = json['summary'];
    final rawStudents = json['students'];
    if (rawClassroom is! Map<String, dynamic> ||
        rawSummary is! Map<String, dynamic> ||
        rawStudents is! List<dynamic>) {
      throw const FormatException('Painel da turma inválido.');
    }
    return ClassroomDashboard(
      classroom: ClassroomDetails.fromJson(rawClassroom),
      generatedAt: _requiredDate(json, 'generated_at'),
      expectedProgressPercent: _requiredNumber(
        json,
        'expected_progress_percent',
      ),
      summary: ClassroomDashboardSummary.fromJson(rawSummary),
      students: rawStudents
          .whereType<Map<String, dynamic>>()
          .map(ClassroomStudent.fromJson)
          .toList(growable: false),
    );
  }
}

class UsageItem {
  const UsageItem({
    required this.courseId,
    required this.eventType,
    required this.targetId,
    required this.count,
    required this.uniqueUsers,
    required this.lastOccurredAt,
  });

  final String courseId;
  final String eventType;
  final String targetId;
  final int count;
  final int uniqueUsers;
  final DateTime lastOccurredAt;

  factory UsageItem.fromJson(Map<String, dynamic> json) => UsageItem(
    courseId: _requiredString(json, 'course_id'),
    eventType: _requiredString(json, 'event_type'),
    targetId: _requiredString(json, 'target_id'),
    count: _requiredInt(json, 'count'),
    uniqueUsers: _requiredInt(json, 'unique_users'),
    lastOccurredAt: _requiredDate(json, 'last_occurred_at'),
  );
}

class UsageSummary {
  const UsageSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.items,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final List<UsageItem> items;

  int get totalInteractions =>
      items.fold(0, (total, item) => total + item.count);

  factory UsageSummary.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException('Resumo de uso inválido.');
    }
    return UsageSummary(
      periodStart: _requiredDate(json, 'period_start'),
      periodEnd: _requiredDate(json, 'period_end'),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(UsageItem.fromJson)
          .toList(growable: false),
    );
  }
}

class StudentHours {
  const StudentHours({
    required this.userId,
    required this.programId,
    required this.courseId,
    required this.plannedHours,
    required this.validatedHours,
    required this.activeUsage,
  });

  final String userId;
  final String programId;
  final String courseId;
  final double plannedHours;
  final double validatedHours;
  final double activeUsage;

  double get completion =>
      plannedHours <= 0 ? 0 : (validatedHours / plannedHours).clamp(0, 1);

  factory StudentHours.fromJson(Map<String, dynamic> json) => StudentHours(
    userId: _requiredString(json, 'user_id'),
    programId: _requiredString(json, 'program_id'),
    courseId: _requiredString(json, 'course_id'),
    plannedHours: _requiredNumber(json, 'planned_hours'),
    validatedHours: _requiredNumber(json, 'validated_hours'),
    activeUsage: _requiredNumber(json, 'active_usage'),
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Campo obrigatório ausente: $key.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || value < 0) {
    throw FormatException('Campo numérico inválido: $key.');
  }
  return value.toInt();
}

double _requiredNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('Campo numérico inválido: $key.');
  }
  return value.toDouble();
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw FormatException('Data inválida: $key.');
  return parsed;
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List<dynamic> || value.any((item) => item is! String)) {
    throw FormatException('Lista inválida: $key.');
  }
  return value.cast<String>();
}

DateTime? _nullableDate(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Data opcional inválida.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const FormatException('Data opcional inválida.');
  return parsed;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is! num || value < 0) {
    throw const FormatException('Número opcional inválido.');
  }
  return value.toInt();
}
