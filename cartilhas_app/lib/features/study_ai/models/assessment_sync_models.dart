import 'package:flutter/foundation.dart';

import 'study_models.dart';

enum AssessmentSyncStatus { localOnly, pending, synced, conflict }

extension AssessmentSyncStatusLabel on AssessmentSyncStatus {
  String get label => switch (this) {
    AssessmentSyncStatus.localOnly => 'Salvo neste aparelho',
    AssessmentSyncStatus.pending => 'Aguardando sincronização',
    AssessmentSyncStatus.synced => 'Sincronizado',
    AssessmentSyncStatus.conflict => 'Conflito de sincronização',
  };
}

@immutable
class AssessmentSyncPayload {
  AssessmentSyncPayload({
    this.assessmentContentId,
    required this.courseId,
    required this.topic,
    required this.mode,
    required this.revision,
    required Map<int, int> answers,
    required Set<int> marked,
    required this.currentIndex,
    required this.remainingSeconds,
    required this.completed,
    required this.score,
    required this.updatedAt,
  }) : answers = Map.unmodifiable(answers),
       marked = Set.unmodifiable(marked);

  factory AssessmentSyncPayload.fromAttempt(
    AssessmentAttempt attempt, {
    required int revision,
  }) {
    final answers = Map<int, int>.fromEntries(
      attempt.answers.entries.where(
        (entry) =>
            entry.key >= 0 &&
            entry.key <= 999 &&
            entry.value >= 0 &&
            entry.value <= 19,
      ),
    );
    final marked = attempt.reviewQuestionIndexes
        .where((index) => index >= 0 && index <= 999)
        .toSet();
    return AssessmentSyncPayload(
      assessmentContentId: attempt.assessmentContentId,
      courseId: attempt.courseId,
      topic: attempt.topic.trim().isEmpty ? attempt.courseId : attempt.topic,
      mode: attempt.mode,
      revision: revision,
      answers: answers,
      marked: marked,
      currentIndex: attempt.currentIndex.clamp(0, 999),
      remainingSeconds: attempt.isCompleted
          ? 0
          : attempt.remainingSeconds.clamp(0, 86400),
      completed: attempt.isCompleted,
      // A pontuação é autoridade do servidor; o cliente nunca envia resultado.
      score: 0,
      updatedAt: attempt.updatedAt.toUtc(),
    );
  }

  factory AssessmentSyncPayload.fromJson(Map<String, dynamic> json) {
    final answers = <int, int>{};
    final rawAnswers = json['answers'];
    if (rawAnswers is Map) {
      for (final entry in rawAnswers.entries) {
        final key = int.tryParse(entry.key.toString());
        final value = (entry.value as num?)?.toInt();
        if (key != null && value != null) answers[key] = value;
      }
    }
    final modeName = json['mode'] as String?;
    return AssessmentSyncPayload(
      assessmentContentId: json['assessment_content_id'] as String?,
      courseId: json['course_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      mode: AssessmentMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => AssessmentMode.quiz,
      ),
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      answers: answers,
      marked: (json['marked'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .toSet(),
      currentIndex: (json['current_index'] as num?)?.toInt() ?? 0,
      remainingSeconds: (json['remaining_seconds'] as num?)?.toInt() ?? 0,
      completed: json['completed'] == true,
      score: (json['score'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String? assessmentContentId;
  final String courseId;
  final String topic;
  final AssessmentMode mode;
  final int revision;
  final Map<int, int> answers;
  final Set<int> marked;
  final int currentIndex;
  final int remainingSeconds;
  final bool completed;
  final int score;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    if (assessmentContentId != null)
      'assessment_content_id': assessmentContentId,
    'course_id': courseId,
    'topic': topic,
    'mode': mode.name,
    'revision': revision,
    'answers': Map.fromEntries(
      (answers.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map(
        (entry) => MapEntry(entry.key.toString(), entry.value),
      ),
    ),
    'marked': marked.toList()..sort(),
    'current_index': currentIndex,
    'remaining_seconds': remainingSeconds,
    'completed': completed,
    'score': score,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  bool hasSameState(AssessmentSyncPayload other) =>
      assessmentContentId == other.assessmentContentId &&
      courseId == other.courseId &&
      topic == other.topic &&
      mode == other.mode &&
      mapEquals(answers, other.answers) &&
      setEquals(marked, other.marked) &&
      currentIndex == other.currentIndex &&
      remainingSeconds == other.remainingSeconds &&
      completed == other.completed;

  bool isExact(AssessmentSyncPayload other) =>
      revision == other.revision &&
      updatedAt.isAtSameMomentAs(other.updatedAt) &&
      hasSameState(other);

  /// Confirma o estado enviado sem confiar na pontuação calculada no aparelho.
  bool isAcceptedResponseFor(AssessmentSyncPayload request) =>
      revision == request.revision &&
      updatedAt.isAtSameMomentAs(request.updatedAt) &&
      hasSameState(request) &&
      score >= 0;

  AssessmentSyncPayload withRevision(int value) => AssessmentSyncPayload(
    assessmentContentId: assessmentContentId,
    courseId: courseId,
    topic: topic,
    mode: mode,
    revision: value,
    answers: answers,
    marked: marked,
    currentIndex: currentIndex,
    remainingSeconds: remainingSeconds,
    completed: completed,
    score: score,
    updatedAt: updatedAt,
  );
}

@immutable
class RemoteAssessmentContent {
  RemoteAssessmentContent({
    required this.id,
    required this.courseId,
    required this.topic,
    required this.mode,
    required this.title,
    required this.durationSeconds,
    required List<StudyQuestion> questions,
    required this.createdAt,
  }) : questions = List.unmodifiable(questions);

  factory RemoteAssessmentContent.fromJson(Map<String, dynamic> json) {
    final id = json['assessment_content_id'] as String? ?? '';
    final courseId = json['course_id'] as String? ?? '';
    final topic = json['topic'] as String? ?? '';
    final modeName = json['mode'] as String?;
    final rawQuestions = json['questions'];
    if (id.isEmpty || courseId.isEmpty || rawQuestions is! List<dynamic>) {
      throw const FormatException('Conteúdo remoto inválido.');
    }
    final answerKey = json['answer_key'];
    final keys = answerKey is List<dynamic> ? answerKey : null;
    final questions = <StudyQuestion>[];
    for (var index = 0; index < rawQuestions.length; index++) {
      final raw = rawQuestions[index];
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Questão remota inválida.');
      }
      final options = (raw['options'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      if (options.length < 2) {
        throw const FormatException('Alternativas remotas inválidas.');
      }
      var correctIndex = -1;
      var explanation = '';
      if (keys != null && index < keys.length) {
        final key = keys[index];
        if (key is! Map<String, dynamic>) {
          throw const FormatException('Gabarito remoto inválido.');
        }
        correctIndex = (key['correct_index'] as num?)?.toInt() ?? -1;
        explanation = key['explanation'] as String? ?? '';
        if (correctIndex < 0 || correctIndex >= options.length) {
          throw const FormatException('Índice de gabarito inválido.');
        }
      }
      questions.add(
        StudyQuestion(
          question: raw['question'] as String? ?? '',
          options: options,
          correctIndex: correctIndex,
          explanation: explanation,
          topic: raw['topic'] as String? ?? topic,
        ),
      );
    }
    if (questions.isEmpty) {
      throw const FormatException('Conteúdo remoto sem questões.');
    }
    return RemoteAssessmentContent(
      id: id,
      courseId: courseId,
      topic: topic,
      mode: AssessmentMode.values.firstWhere(
        (value) => value.name == modeName,
        orElse: () => throw const FormatException('Modo remoto inválido.'),
      ),
      title: json['title'] as String? ?? 'Atividade',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      questions: questions,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String courseId;
  final String topic;
  final AssessmentMode mode;
  final String title;
  final int durationSeconds;
  final List<StudyQuestion> questions;
  final DateTime createdAt;

  bool get hasAnswerKey => questions.every((item) => item.correctIndex >= 0);
}

@immutable
class RemoteAssessmentAttempt {
  const RemoteAssessmentAttempt({
    required this.attemptId,
    required this.payload,
  });

  factory RemoteAssessmentAttempt.fromJson(Map<String, dynamic> json) {
    final attemptId = json['attempt_id'] as String? ?? '';
    if (attemptId.isEmpty) {
      throw const FormatException('Tentativa remota sem identificador.');
    }
    return RemoteAssessmentAttempt(
      attemptId: attemptId,
      payload: AssessmentSyncPayload.fromJson(json),
    );
  }

  final String attemptId;
  final AssessmentSyncPayload payload;

  Map<String, dynamic> toJson() => {
    'attempt_id': attemptId,
    ...payload.toJson(),
  };
}

@immutable
class AssessmentPendingRevision {
  const AssessmentPendingRevision({
    required this.payload,
    this.wasAttempted = false,
  });

  factory AssessmentPendingRevision.fromJson(Map<String, dynamic> json) =>
      AssessmentPendingRevision(
        payload: AssessmentSyncPayload.fromJson(
          json['payload'] as Map<String, dynamic>? ?? const {},
        ),
        wasAttempted: json['was_attempted'] == true,
      );

  final AssessmentSyncPayload payload;
  final bool wasAttempted;

  Map<String, dynamic> toJson() => {
    'payload': payload.toJson(),
    'was_attempted': wasAttempted,
  };
}

@immutable
class AssessmentSyncRecord {
  AssessmentSyncRecord({
    required this.attemptId,
    required this.status,
    required this.confirmedRevision,
    required List<AssessmentPendingRevision> pending,
    this.confirmedPayload,
    this.remoteConflict,
    this.lastError,
  }) : pending = List.unmodifiable(pending);

  factory AssessmentSyncRecord.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    final confirmedJson = json['confirmed_payload'];
    final conflictJson = json['remote_conflict'];
    return AssessmentSyncRecord(
      attemptId: json['attempt_id'] as String? ?? '',
      status: AssessmentSyncStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => AssessmentSyncStatus.localOnly,
      ),
      confirmedRevision: (json['confirmed_revision'] as num?)?.toInt() ?? 0,
      confirmedPayload: confirmedJson is Map<String, dynamic>
          ? AssessmentSyncPayload.fromJson(confirmedJson)
          : null,
      pending: (json['pending'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AssessmentPendingRevision.fromJson)
          .toList(),
      remoteConflict: conflictJson is Map<String, dynamic>
          ? RemoteAssessmentAttempt.fromJson(conflictJson)
          : null,
      lastError: json['last_error'] as String?,
    );
  }

  final String attemptId;
  final AssessmentSyncStatus status;
  final int confirmedRevision;
  final AssessmentSyncPayload? confirmedPayload;
  final List<AssessmentPendingRevision> pending;
  final RemoteAssessmentAttempt? remoteConflict;
  final String? lastError;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'attempt_id': attemptId,
      'status': status.name,
      'confirmed_revision': confirmedRevision,
      'pending': pending.map((item) => item.toJson()).toList(),
    };
    final confirmed = confirmedPayload;
    if (confirmed != null) json['confirmed_payload'] = confirmed.toJson();
    final conflict = remoteConflict;
    if (conflict != null) json['remote_conflict'] = conflict.toJson();
    final error = lastError;
    if (error != null) json['last_error'] = error;
    return json;
  }
}
