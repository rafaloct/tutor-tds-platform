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
    this.origin = AssessmentOrigin.practice,
    this.publishedLineage,
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
  }) : assert(
         origin != AssessmentOrigin.publishedBlock || publishedLineage != null,
       ),
       answers = Map.unmodifiable(answers),
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
      origin: attempt.origin,
      publishedLineage: attempt.publishedContext?.lineage,
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
    final origin = AssessmentOriginValue.fromApi(json['origin']);
    final publishedLineage = origin == AssessmentOrigin.publishedBlock
        ? PublishedAssessmentLineage.fromJson(json)
        : null;
    return AssessmentSyncPayload(
      assessmentContentId: json['assessment_content_id'] as String?,
      origin: origin,
      publishedLineage: publishedLineage,
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
  final AssessmentOrigin origin;
  final PublishedAssessmentLineage? publishedLineage;
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
    if (origin == AssessmentOrigin.publishedBlock) ...{
      'origin': origin.apiValue,
      ...publishedLineage!.toJson(),
    },
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
      _sameContentIdentity(other) &&
      origin == other.origin &&
      (origin == AssessmentOrigin.practice ||
          publishedLineage!.sameAs(other.publishedLineage)) &&
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

  bool _sameContentIdentity(AssessmentSyncPayload other) {
    if (origin == AssessmentOrigin.publishedBlock &&
        other.origin == AssessmentOrigin.publishedBlock) {
      // The published snapshot is authoritative. The request omits this ID and
      // the server returns the content record it resolved for the block.
      return assessmentContentId == null ||
          other.assessmentContentId == null ||
          assessmentContentId == other.assessmentContentId;
    }
    return assessmentContentId == other.assessmentContentId;
  }

  AssessmentSyncPayload withRevision(int value) => AssessmentSyncPayload(
    assessmentContentId: assessmentContentId,
    origin: origin,
    publishedLineage: publishedLineage,
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

  AssessmentSyncPayload withUpdatedAt(DateTime value) => AssessmentSyncPayload(
    assessmentContentId: assessmentContentId,
    origin: origin,
    publishedLineage: publishedLineage,
    courseId: courseId,
    topic: topic,
    mode: mode,
    revision: revision,
    answers: answers,
    marked: marked,
    currentIndex: currentIndex,
    remainingSeconds: remainingSeconds,
    completed: completed,
    score: score,
    updatedAt: value.toUtc(),
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
      var correctIndexes = <int>{};
      var graded = true;
      var explanation = '';
      if (keys != null && index < keys.length) {
        final key = keys[index];
        if (key is! Map<String, dynamic>) {
          throw const FormatException('Gabarito remoto inválido.');
        }
        final multiple = key['correct_indices'];
        if (multiple is List<dynamic>) {
          correctIndexes = multiple
              .whereType<num>()
              .map((value) => value.toInt())
              .toSet();
          graded = key['graded'] as bool? ?? true;
          correctIndex = correctIndexes.isEmpty ? -1 : correctIndexes.first;
        } else {
          correctIndex = (key['correct_index'] as num?)?.toInt() ?? -1;
          correctIndexes = correctIndex < 0 ? {} : {correctIndex};
        }
        explanation = key['explanation'] as String? ?? '';
        if ((graded && correctIndexes.isEmpty) ||
            correctIndexes.any(
              (index) => index < 0 || index >= options.length,
            )) {
          throw const FormatException('Índice de gabarito inválido.');
        }
      }
      questions.add(
        StudyQuestion(
          question: raw['question'] as String? ?? '',
          options: options,
          correctIndex: correctIndex,
          correctIndexes: correctIndexes,
          graded: graded,
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

  bool get hasAnswerKey =>
      questions.every((item) => !item.graded || item.correctIndexes.isNotEmpty);
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
    this.localContext,
  }) : pending = List.unmodifiable(pending);

  factory AssessmentSyncRecord.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    final confirmedJson = json['confirmed_payload'];
    final conflictJson = json['remote_conflict'];
    final localContextJson = json['local_context'];
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
      localContext: localContextJson is Map<String, dynamic>
          ? PublishedAssessmentContext.fromJson(localContextJson)
          : null,
    );
  }

  final String attemptId;
  final AssessmentSyncStatus status;
  final int confirmedRevision;
  final AssessmentSyncPayload? confirmedPayload;
  final List<AssessmentPendingRevision> pending;
  final RemoteAssessmentAttempt? remoteConflict;
  final String? lastError;
  final PublishedAssessmentContext? localContext;

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
    final context = localContext;
    if (context != null) json['local_context'] = context.toJson();
    return json;
  }
}
