class CertificateRequestEligibility {
  const CertificateRequestEligibility({
    required this.requiredSeconds,
    required this.validatedSeconds,
    required this.completed,
    required this.eligible,
  });

  final int requiredSeconds;
  final int validatedSeconds;
  final bool completed;
  final bool eligible;

  factory CertificateRequestEligibility.fromJson(Map<String, dynamic> json) =>
      CertificateRequestEligibility(
        requiredSeconds: _integer(json, 'required_seconds', minimum: 0),
        validatedSeconds: _integer(json, 'validated_seconds', minimum: 0),
        completed: _boolean(json, 'completed'),
        eligible: _boolean(json, 'eligible'),
      );
}

class CertificateRequestContext {
  const CertificateRequestContext({
    required this.enrollmentId,
    required this.programName,
    required this.courseVersionId,
    required this.courseTitle,
    required this.eligibility,
    this.classId,
    this.className,
  });

  final String enrollmentId;
  final String programName;
  final String? classId;
  final String? className;
  final String courseVersionId;
  final String courseTitle;
  final CertificateRequestEligibility eligibility;

  factory CertificateRequestContext.fromJson(Map<String, dynamic> json) =>
      CertificateRequestContext(
        enrollmentId: _text(json, 'enrollment_id'),
        programName: _text(json, 'program_name'),
        classId: _optionalText(json, 'class_id'),
        className: _optionalText(json, 'class_name'),
        courseVersionId: _text(json, 'course_version_id'),
        courseTitle: _text(json, 'course_title'),
        eligibility: CertificateRequestEligibility.fromJson(
          _object(json['eligibility']),
        ),
      );
}

class CertificateRequest {
  const CertificateRequest({
    required this.id,
    required this.enrollmentId,
    required this.courseId,
    required this.courseVersionId,
    required this.programId,
    required this.holderName,
    required this.courseTitle,
    required this.programName,
    required this.institutionName,
    required this.status,
    required this.revision,
    required this.requestedAt,
    required this.eligibility,
    this.classId,
    this.reviewedAt,
    this.reviewReason,
    this.className,
  });

  final String id;
  final String enrollmentId;
  final String courseId;
  final String courseVersionId;
  final String? classId;
  final String programId;
  final String holderName;
  final String courseTitle;
  final String programName;
  final String institutionName;
  final String? className;
  final String status;
  final int revision;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? reviewReason;
  final CertificateRequestEligibility eligibility;

  factory CertificateRequest.fromJson(Map<String, dynamic> json) {
    final status = _text(json, 'status');
    if (!{'pending', 'approved', 'rejected'}.contains(status)) {
      throw const FormatException('Estado de solicitação inválido.');
    }
    return CertificateRequest(
      id: _text(json, 'id'),
      enrollmentId: _text(json, 'enrollment_id'),
      courseId: _text(json, 'course_id'),
      courseVersionId: _text(json, 'course_version_id'),
      classId: _optionalText(json, 'class_id'),
      programId: _text(json, 'program_id'),
      holderName: _text(json, 'holder_name'),
      courseTitle: _text(json, 'course_title'),
      programName: _text(json, 'program_name'),
      institutionName: _text(json, 'institution_name'),
      className: _optionalText(json, 'class_name'),
      status: status,
      revision: _integer(json, 'revision', minimum: 1),
      requestedAt: _date(json, 'requested_at'),
      reviewedAt: json['reviewed_at'] == null
          ? null
          : _date(json, 'reviewed_at'),
      reviewReason: _optionalText(json, 'review_reason', allowEmpty: true),
      eligibility: CertificateRequestEligibility.fromJson(
        _object(json['eligibility']),
      ),
    );
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Dados de solicitação inválidos.');
  }
  return value;
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Campo textual obrigatório inválido.');
  }
  return value;
}

String? _optionalText(
  Map<String, dynamic> json,
  String key, {
  bool allowEmpty = false,
}) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw const FormatException('Campo textual opcional inválido.');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key, {required int minimum}) {
  final value = json[key];
  if (value is! int || value < minimum) {
    throw const FormatException('Valor numérico inválido.');
  }
  return value;
}

bool _boolean(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw const FormatException('Valor booleano inválido.');
  return value;
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = _text(json, key);
  final parts = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (parts == null) {
    throw const FormatException('Data da solicitação inválida.');
  }
  final year = int.parse(parts[1]!);
  final month = int.parse(parts[2]!);
  final day = int.parse(parts[3]!);
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > DateTime.utc(year, month + 1, 0).day ||
      int.parse(parts[4]!) > 23 ||
      int.parse(parts[5]!) > 59 ||
      int.parse(parts[6]!) > 59) {
    throw const FormatException('Data da solicitação inválida.');
  }
  final date = DateTime.tryParse(value);
  if (date == null) {
    throw const FormatException('Data da solicitação inválida.');
  }
  return date.toUtc();
}
