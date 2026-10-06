class EvidenceSession {
  const EvidenceSession({
    required this.id,
    required this.classId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.tokenExpiresAt,
    required this.tokenVersion,
    this.checkinToken,
    this.checkinCode,
  });

  final String id;
  final String classId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final DateTime tokenExpiresAt;
  final int tokenVersion;
  final String? checkinToken;
  final String? checkinCode;

  factory EvidenceSession.fromJson(Map<String, dynamic> json) =>
      EvidenceSession(
        id: _string(json, 'id'),
        classId: _string(json, 'class_id'),
        startsAt: _date(json, 'starts_at'),
        endsAt: _date(json, 'ends_at'),
        status: _string(json, 'status'),
        tokenExpiresAt: _date(json, 'token_expires_at'),
        tokenVersion: _int(json, 'token_version'),
        checkinToken: _optionalString(json['checkin_token']),
        checkinCode: _optionalString(json['checkin_code']),
      );
}

class EvidenceSessionPage {
  EvidenceSessionPage({
    required List<EvidenceSession> sessions,
    required this.total,
    required this.limit,
    required this.offset,
  }) : sessions = List.unmodifiable(sessions);

  final List<EvidenceSession> sessions;
  final int total;
  final int limit;
  final int offset;

  factory EvidenceSessionPage.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['sessions'];
    if (rawSessions is! List<dynamic>) {
      throw const FormatException('Lista de sessões inválida.');
    }
    return EvidenceSessionPage(
      sessions: rawSessions
          .whereType<Map<String, dynamic>>()
          .map(EvidenceSession.fromJson)
          .toList(growable: false),
      total: _int(json, 'total'),
      limit: _int(json, 'limit'),
      offset: _int(json, 'offset'),
    );
  }
}

class EvidenceCheckin {
  const EvidenceCheckin({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.kind,
    required this.occurredAt,
    required this.method,
    required this.evidenceId,
  });

  final String id;
  final String sessionId;
  final String userId;
  final String kind;
  final DateTime occurredAt;
  final String method;
  final String evidenceId;

  factory EvidenceCheckin.fromJson(Map<String, dynamic> json) =>
      EvidenceCheckin(
        id: _string(json, 'id'),
        sessionId: _string(json, 'session_id'),
        userId: _string(json, 'user_id'),
        kind: _string(json, 'kind'),
        occurredAt: _date(json, 'occurred_at'),
        method: _string(json, 'method'),
        evidenceId: _string(json, 'evidence_id'),
      );
}

class EvidenceImportItemDraft {
  const EvidenceImportItemDraft({
    required this.itemDigest,
    required this.evidenceType,
    required this.occurredAt,
    this.userId,
    this.sessionId,
    this.objectReference,
    this.metadata = const {},
  });

  static const allowedMetadataKeys = {
    'message_count',
    'mime_type',
    'source_item_id',
    'page_count',
  };

  final String itemDigest;
  final String evidenceType;
  final DateTime occurredAt;
  final String? userId;
  final String? sessionId;
  final String? objectReference;
  final Map<String, String> metadata;

  Map<String, dynamic> toJson() {
    if (!RegExp(r'^[0-9a-f]{64,128}$').hasMatch(itemDigest)) {
      throw const FormatException('Digest do item inválido.');
    }
    if (!metadata.keys.every(allowedMetadataKeys.contains) ||
        metadata.values.any(
          (value) => value.length > 120 || value.contains('\n'),
        )) {
      throw const FormatException(
        'Metadados devem ser estruturados e não podem conter conteúdo bruto.',
      );
    }
    if (objectReference?.contains('://') ?? false) {
      throw const FormatException(
        'Use somente identificador privado, nunca uma URL pública.',
      );
    }
    return {
      'item_digest': itemDigest,
      'evidence_type': evidenceType,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      if (userId?.trim().isNotEmpty ?? false) 'user_id': userId!.trim(),
      if (sessionId?.trim().isNotEmpty ?? false)
        'session_id': sessionId!.trim(),
      if (objectReference?.trim().isNotEmpty ?? false)
        'object_reference': objectReference!.trim(),
      'metadata': metadata,
    };
  }
}

class EvidenceImportRecord {
  const EvidenceImportRecord({
    required this.id,
    required this.classId,
    required this.sourceType,
    required this.status,
    required this.retentionUntil,
    required this.sourceDigest,
    required this.evidenceIds,
  });

  final String id;
  final String classId;
  final String sourceType;
  final String status;
  final DateTime retentionUntil;
  final String sourceDigest;
  final List<String> evidenceIds;

  factory EvidenceImportRecord.fromJson(Map<String, dynamic> json) =>
      EvidenceImportRecord(
        id: _string(json, 'id'),
        classId: _string(json, 'class_id'),
        sourceType: _string(json, 'source_type'),
        status: _string(json, 'status'),
        retentionUntil: _date(json, 'retention_until'),
        sourceDigest: _string(json, 'source_digest'),
        evidenceIds: (json['evidence_ids'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
}

class EvidenceExceptionItem {
  const EvidenceExceptionItem({
    required this.code,
    required this.evidenceId,
    this.userId,
  });

  final String code;
  final String evidenceId;
  final String? userId;

  factory EvidenceExceptionItem.fromJson(Map<String, dynamic> json) =>
      EvidenceExceptionItem(
        code: _string(json, 'code'),
        evidenceId: _string(json, 'evidence_id'),
        userId: _optionalString(json['user_id']),
      );
}

class EvidenceReviewResult {
  const EvidenceReviewResult({
    required this.evidenceId,
    required this.decision,
    required this.reasonCode,
    required this.decidedAt,
  });

  final String evidenceId;
  final String decision;
  final String reasonCode;
  final DateTime decidedAt;

  factory EvidenceReviewResult.fromJson(Map<String, dynamic> json) =>
      EvidenceReviewResult(
        evidenceId: _string(json, 'evidence_id'),
        decision: _string(json, 'decision'),
        reasonCode: _string(json, 'reason_code'),
        decidedAt: _date(json, 'decided_at'),
      );
}

class EvidenceReport {
  const EvidenceReport({
    required this.id,
    required this.classId,
    required this.sessionId,
    required this.generatedAt,
    required this.reportDigest,
    required this.summary,
  });

  final String id;
  final String classId;
  final String sessionId;
  final DateTime generatedAt;
  final String reportDigest;
  final Map<String, dynamic> summary;

  factory EvidenceReport.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    if (summary is! Map<String, dynamic>) {
      throw const FormatException('Resumo do relatório inválido.');
    }
    return EvidenceReport(
      id: _string(json, 'id'),
      classId: _string(json, 'class_id'),
      sessionId: _string(json, 'session_id'),
      generatedAt: _date(json, 'generated_at'),
      reportDigest: _string(json, 'report_digest'),
      summary: Map.unmodifiable(summary),
    );
  }
}

class SessionPresence {
  const SessionPresence({
    required this.userId,
    required this.userName,
    required this.enrollmentId,
    required this.status,
    required this.revision,
    required this.checkinCount,
    required this.checkoutCount,
    required this.activityCount,
    this.reason,
    this.decidedAt,
  });
  final String userId, userName, enrollmentId, status;
  final int revision, checkinCount, checkoutCount, activityCount;
  final String? reason;
  final DateTime? decidedAt;
  static const statuses = {
    'pending',
    'suggested_present',
    'confirmed_present',
    'justified_absence',
    'absent',
  };
  factory SessionPresence.fromJson(Map<String, dynamic> json) {
    final status = _string(json, 'status');
    if (!statuses.contains(status)) {
      throw const FormatException('Presença inválida.');
    }
    int count(String key) {
      final value = json[key];
      if (value is! int || value < 0) {
        throw const FormatException('Contagem inválida.');
      }
      return value;
    }

    return SessionPresence(
      userId: _string(json, 'user_id'),
      userName: _string(json, 'user_name'),
      enrollmentId: _string(json, 'enrollment_id'),
      status: status,
      revision: count('revision'),
      checkinCount: count('checkin_count'),
      checkoutCount: count('checkout_count'),
      activityCount: count('activity_count'),
      reason: _optionalString(json['reason']),
      decidedAt: json['decided_at'] == null ? null : _date(json, 'decided_at'),
    );
  }
}

class OfficialAttendanceDecision {
  OfficialAttendanceDecision.fromJson(Map<String, dynamic> json)
    : revision = _int(json, 'revision'),
      status = _string(json, 'status'),
      reason = _string(json, 'reason'),
      makeupSessionId = json['makeup_session_id'] as String?,
      decidedAt = _string(json, 'decided_at');
  final int revision;
  final String status, reason, decidedAt;
  final String? makeupSessionId;
}

class OfficialAttendancePage {
  OfficialAttendancePage.fromJson(Map<String, dynamic> json)
    : items = (json['items'] as List)
          .map(
            (row) => OfficialAttendanceDecision.fromJson(
              row as Map<String, dynamic>,
            ),
          )
          .toList(),
      total = _int(json, 'total'),
      canDecide = json['can_decide'] == true;
  final List<OfficialAttendanceDecision> items;
  final int total;
  final bool canDecide;
}

class SessionPresencePage {
  const SessionPresencePage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
    required this.sessionStatus,
  });
  final List<SessionPresence> items;
  final int total, offset, limit;
  final String sessionStatus;
  factory SessionPresencePage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final status = _string(json, 'session_status');
    if (items is! List || !{'open', 'closed'}.contains(status)) {
      throw const FormatException('Lista de presença inválida.');
    }
    return SessionPresencePage(
      items: List.unmodifiable(
        items.map(
          (item) => SessionPresence.fromJson(item as Map<String, dynamic>),
        ),
      ),
      total: _int(json, 'total'),
      offset: _int(json, 'offset'),
      limit: _int(json, 'limit'),
      sessionStatus: status,
    );
  }
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key inválido.');
  }
  return value;
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key inválido.');
  return value.toInt();
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key inválido.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key inválido.');
  return parsed;
}
