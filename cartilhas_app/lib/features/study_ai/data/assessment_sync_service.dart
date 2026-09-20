import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../auth/data/auth_repository.dart';
import '../models/assessment_sync_models.dart';
import '../models/study_models.dart';
import 'assessment_sync_queue.dart';

abstract interface class AssessmentSyncCoordinator {
  Future<AssessmentSyncRecord> queueAttempt(AssessmentAttempt attempt);
  Future<AssessmentSyncRecord> queueAndSync(AssessmentAttempt attempt);
  Future<AssessmentSyncRecord?> status(String attemptId);
  Future<AssessmentSyncRecord> retry(String attemptId);
  Future<List<RemoteAssessmentAttempt>> discoverIncomplete({
    required String courseId,
    required AssessmentMode mode,
  });
  Future<AssessmentAttempt> hydrateRemoteAttempt(
    RemoteAssessmentAttempt remote,
  );
  Future<AssessmentSyncRecord> registerDiscovered(
    AssessmentAttempt local,
    RemoteAssessmentAttempt remote,
  );
  Future<AssessmentSyncRecord> refreshConflict(String attemptId);
  Future<AssessmentAttempt> resolveUsingRemote(AssessmentAttempt local);
  Future<AssessmentSyncRecord> resolveKeepingLocal(AssessmentAttempt local);
}

class AssessmentSyncConflictException implements Exception {
  const AssessmentSyncConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AssessmentLegacyContentException extends AssessmentSyncConflictException {
  const AssessmentLegacyContentException()
    : super(
        'Esta tentativa foi criada antes da retomada entre dispositivos. '
        'O progresso continua registrado, mas as questões não podem ser reconstruídas com segurança.',
      );
}

class AssessmentSyncService implements AssessmentSyncCoordinator {
  AssessmentSyncService({
    required this.apiUrl,
    required this.authRepository,
    this.queue = const AssessmentSyncQueue(),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiUrl;
  final AuthRepository authRepository;
  final AssessmentSyncQueue queue;
  final http.Client _client;
  final Map<String, AssessmentAttempt> _localAttempts = {};
  final Set<String> _registeredContentIds = {};
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<AssessmentSyncRecord> queueAttempt(AssessmentAttempt attempt) {
    _localAttempts[attempt.id] = attempt;
    return queue.enqueue(attempt);
  }

  @override
  Future<AssessmentSyncRecord> queueAndSync(AssessmentAttempt attempt) async {
    _localAttempts[attempt.id] = attempt;
    final queued = await queue.enqueue(attempt);
    if (queued.lastError == 'active_enrollment_required') return queued;
    return _serialize(() => _flush(attempt.id, fallback: queued));
  }

  @override
  Future<AssessmentAttempt> hydrateRemoteAttempt(
    RemoteAssessmentAttempt remote,
  ) async {
    final contentId = remote.payload.assessmentContentId;
    if (contentId == null || contentId.isEmpty) {
      throw const AssessmentLegacyContentException();
    }
    if (apiUrl.trim().isEmpty ||
        !authRepository.isConfigured ||
        !await authRepository.hasSession()) {
      throw const AssessmentSyncConflictException(
        'Conecte-se à internet e entre na conta para recuperar as questões.',
      );
    }
    final response = await authRepository.authorized(
      (accessToken) => _client
          .get(
            _uri('/assessment-attempts/${remote.attemptId}/content'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 12)),
    );
    if (response.statusCode == 409 &&
        _conflictCode(response.body) == 'legacy_attempt_without_content') {
      throw const AssessmentLegacyContentException();
    }
    if (response.statusCode != 200) {
      throw AssessmentSyncConflictException(
        'Não foi possível recuperar as questões (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AssessmentSyncConflictException(
        'O conteúdo recebido é inválido.',
      );
    }
    final content = RemoteAssessmentContent.fromJson(decoded);
    final payload = remote.payload;
    if (content.id != contentId ||
        content.courseId != payload.courseId ||
        content.topic != payload.topic ||
        content.mode != payload.mode) {
      throw const AssessmentSyncConflictException(
        'O conteúdo recuperado não corresponde à tentativa.',
      );
    }
    if (payload.completed && !content.hasAnswerKey) {
      throw const AssessmentSyncConflictException(
        'O servidor ainda não liberou o gabarito desta tentativa concluída.',
      );
    }
    final answers = Map<int, int>.fromEntries(
      payload.answers.entries.where(
        (entry) =>
            entry.key >= 0 &&
            entry.key < content.questions.length &&
            entry.value >= 0 &&
            entry.value < content.questions[entry.key].options.length,
      ),
    );
    final marked = payload.marked
        .where((index) => index >= 0 && index < content.questions.length)
        .toSet();
    final deck = AssessmentDeck(
      title: content.title,
      durationMinutes: content.durationSeconds == 0
          ? 0
          : (content.durationSeconds / 60).ceil(),
      items: content.questions,
    );
    final attempt = AssessmentAttempt(
      id: remote.attemptId,
      assessmentContentId: content.id,
      courseId: content.courseId,
      topic: content.topic,
      mode: content.mode,
      difficulty: StudyDifficulty.intermediate,
      totalQuestions: content.questions.length,
      deck: deck,
      answers: answers,
      reviewQuestionIndexes: marked,
      currentIndex: payload.currentIndex.clamp(
        0,
        (content.questions.length - 1).clamp(0, 999),
      ),
      remainingSeconds: payload.remainingSeconds,
      score: payload.score,
      weakTopics: payload.completed ? _weakTopics(deck, answers) : const [],
      isCompleted: payload.completed,
      createdAt: content.createdAt,
      updatedAt: payload.updatedAt,
    );
    _localAttempts[attempt.id] = attempt;
    await queue.acceptRemote(attempt.id, remote);
    return attempt;
  }

  @override
  Future<AssessmentSyncRecord?> status(String attemptId) =>
      queue.read(attemptId);

  @override
  Future<AssessmentSyncRecord> retry(String attemptId) async {
    final current = await queue.read(attemptId);
    if (current == null) {
      throw const AssessmentSyncConflictException(
        'Não há uma tentativa pendente para sincronizar.',
      );
    }
    return _serialize(() => _flush(attemptId, fallback: current));
  }

  @override
  Future<List<RemoteAssessmentAttempt>> discoverIncomplete({
    required String courseId,
    required AssessmentMode mode,
  }) async {
    if (apiUrl.trim().isEmpty || !authRepository.isConfigured) return const [];
    try {
      if (!await authRepository.hasSession()) return const [];
      final uri = _uri('/assessment-attempts').replace(
        queryParameters: {
          'course_id': courseId,
          'mode': mode.name,
          'completed': 'false',
          'limit': '50',
          'offset': '0',
        },
      );
      final response = await authRepository.authorized(
        (accessToken) => _client
            .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
            .timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['attempts'] is! List<dynamic>) {
        return const [];
      }
      final attempts = <RemoteAssessmentAttempt>[];
      for (final item in decoded['attempts'] as List<dynamic>) {
        if (item is! Map<String, dynamic>) continue;
        try {
          final attempt = RemoteAssessmentAttempt.fromJson(item);
          if (attempt.payload.courseId == courseId &&
              attempt.payload.mode == mode &&
              !attempt.payload.completed) {
            attempts.add(attempt);
          }
        } on FormatException {
          // Um item inválido não oculta os demais registros válidos.
        }
      }
      attempts.sort(
        (a, b) => b.payload.updatedAt.compareTo(a.payload.updatedAt),
      );
      return List.unmodifiable(attempts);
    } on Object {
      return const [];
    }
  }

  @override
  Future<AssessmentSyncRecord> registerDiscovered(
    AssessmentAttempt local,
    RemoteAssessmentAttempt remote,
  ) async {
    final payload = remote.payload;
    if (remote.attemptId != local.id ||
        payload.courseId != local.courseId ||
        payload.topic != local.topic ||
        payload.mode != local.mode) {
      throw const AssessmentSyncConflictException(
        'A tentativa online não corresponde a esta atividade local.',
      );
    }
    final localPayload = AssessmentSyncPayload.fromAttempt(
      local,
      revision: payload.revision,
    );
    if (payload.hasSameState(localPayload)) {
      return queue.acceptRemote(local.id, remote);
    }
    await queue.enqueue(local);
    return queue.markConflict(local.id, remote, 'remote_revision_detected');
  }

  @override
  Future<AssessmentSyncRecord> refreshConflict(String attemptId) async {
    final current = await queue.read(attemptId);
    if (current == null) {
      throw const AssessmentSyncConflictException(
        'Não há uma tentativa pendente para consultar.',
      );
    }
    if (apiUrl.trim().isEmpty ||
        !authRepository.isConfigured ||
        !await authRepository.hasSession()) {
      return current;
    }
    final remote = await _fetchRemote(attemptId);
    if (remote == null) return current;
    return queue.markConflict(
      attemptId,
      remote,
      current.lastError ?? 'revision_conflict',
    );
  }

  @override
  Future<AssessmentAttempt> resolveUsingRemote(AssessmentAttempt local) async {
    final record = await queue.read(local.id);
    final remote = record?.remoteConflict;
    if (remote == null) {
      throw const AssessmentSyncConflictException(
        'A versão do servidor ainda não pôde ser consultada.',
      );
    }
    if (remote.payload.courseId != local.courseId ||
        remote.payload.topic != local.topic ||
        remote.payload.mode != local.mode) {
      throw const AssessmentSyncConflictException(
        'A tentativa remota não corresponde a esta atividade.',
      );
    }
    return hydrateRemoteAttempt(remote);
  }

  @override
  Future<AssessmentSyncRecord> resolveKeepingLocal(
    AssessmentAttempt local,
  ) async {
    final record = await queue.read(local.id);
    final remote = record?.remoteConflict;
    if (remote == null) {
      throw const AssessmentSyncConflictException(
        'A versão do servidor ainda não pôde ser consultada.',
      );
    }
    if (remote.payload.completed) {
      throw const AssessmentSyncConflictException(
        'A tentativa do servidor já foi concluída e não pode ser alterada.',
      );
    }
    final queued = await queue.replaceWithLocal(local, remote);
    return _serialize(() => _flush(local.id, fallback: queued));
  }

  Future<AssessmentSyncRecord> _flush(
    String attemptId, {
    required AssessmentSyncRecord fallback,
  }) async {
    var current = await queue.read(attemptId) ?? fallback;
    if (current.status == AssessmentSyncStatus.conflict ||
        current.pending.isEmpty) {
      return current;
    }
    if (apiUrl.trim().isEmpty || !authRepository.isConfigured) {
      return queue.markPending(attemptId, 'api_unavailable');
    }
    try {
      if (!await authRepository.hasSession()) {
        return queue.markPending(attemptId, 'session_required');
      }
    } on Object {
      return queue.markPending(attemptId, 'session_unavailable');
    }

    final local = _localAttempts[attemptId];
    if (local != null && local.deck.hasAnswerKey) {
      final contentError = await _ensureContent(local);
      if (contentError != null) {
        return queue.markPending(attemptId, contentError);
      }
    } else if (current.pending.first.payload.assessmentContentId == null) {
      return queue.markPending(attemptId, 'legacy_attempt_without_content');
    }

    while (current.pending.isNotEmpty) {
      final pending = current.pending.first;
      final revision = pending.payload.revision;
      current = await queue.markAttempted(attemptId, revision);
      try {
        final response = await authRepository.authorized(
          (accessToken) => _client
              .put(
                _uri('/assessment-attempts/$attemptId'),
                headers: {
                  'Authorization': 'Bearer $accessToken',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(pending.payload.toJson()),
              )
              .timeout(const Duration(seconds: 12)),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          final remote = _decodeRemote(response.body);
          if (!remote.payload.isAcceptedResponseFor(pending.payload) ||
              remote.attemptId != attemptId) {
            return queue.markPending(attemptId, 'invalid_server_response');
          }
          current = await queue.markSuccess(attemptId, remote);
          continue;
        }
        if (response.statusCode == 409) {
          final conflictCode = _conflictCode(response.body);
          final remote = await _fetchRemote(attemptId);
          return queue.markConflict(attemptId, remote, conflictCode);
        }
        if (response.statusCode == 403) {
          return queue.markPending(attemptId, 'active_enrollment_required');
        }
        if (response.statusCode == 401) {
          return queue.markPending(attemptId, 'session_required');
        }
        return queue.markPending(attemptId, 'server_${response.statusCode}');
      } on Object {
        return queue.markPending(attemptId, 'network_unavailable');
      }
    }
    return current;
  }

  Future<String?> _ensureContent(AssessmentAttempt attempt) async {
    if (_registeredContentIds.contains(attempt.assessmentContentId)) {
      return null;
    }
    final idPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{0,179}$');
    if (!idPattern.hasMatch(attempt.assessmentContentId)) {
      return 'invalid_assessment_content_id';
    }
    final durationSeconds = attempt.mode == AssessmentMode.exam
        ? (attempt.deck.durationMinutes.clamp(1, 1440) * 60)
        : 0;
    final body = {
      'course_id': attempt.courseId,
      'topic': attempt.topic,
      'mode': attempt.mode.name,
      'title': attempt.deck.title,
      'duration_seconds': durationSeconds,
      'questions': [
        for (final question in attempt.deck.items)
          {
            'question': question.question,
            'options': question.options,
            'correct_index': question.correctIndex,
            'explanation': question.explanation,
            'topic': question.topic,
          },
      ],
    };
    try {
      final response = await authRepository.authorized(
        (accessToken) => _client
            .put(
              _uri('/assessment-contents/${attempt.assessmentContentId}'),
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          return 'invalid_content_response';
        }
        final content = RemoteAssessmentContent.fromJson(decoded);
        if (content.id != attempt.assessmentContentId ||
            content.courseId != attempt.courseId ||
            content.topic != attempt.topic ||
            content.mode != attempt.mode ||
            content.title != attempt.deck.title ||
            content.durationSeconds != durationSeconds ||
            content.questions.length != attempt.deck.items.length ||
            !_sameQuestions(content.questions, attempt.deck.items)) {
          return 'invalid_content_response';
        }
        _registeredContentIds.add(attempt.assessmentContentId);
        return null;
      }
      if (response.statusCode == 403) return 'active_enrollment_required';
      if (response.statusCode == 401) return 'session_required';
      if (response.statusCode == 409) return _conflictCode(response.body);
      return 'content_server_${response.statusCode}';
    } on Object {
      return 'network_unavailable';
    }
  }

  bool _sameQuestions(List<StudyQuestion> remote, List<StudyQuestion> local) {
    for (var index = 0; index < local.length; index++) {
      final left = remote[index];
      final right = local[index];
      if (left.question != right.question ||
          !listEquals(left.options, right.options) ||
          left.topic != right.topic) {
        return false;
      }
    }
    return true;
  }

  Future<RemoteAssessmentAttempt?> _fetchRemote(String attemptId) async {
    try {
      final response = await authRepository.authorized(
        (accessToken) => _client
            .get(
              _uri('/assessment-attempts/$attemptId'),
              headers: {'Authorization': 'Bearer $accessToken'},
            )
            .timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode != 200) return null;
      final remote = _decodeRemote(response.body);
      return remote.attemptId == attemptId ? remote : null;
    } on Object {
      return null;
    }
  }

  RemoteAssessmentAttempt _decodeRemote(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Resposta de sincronização inválida.');
    }
    return RemoteAssessmentAttempt.fromJson(decoded);
  }

  String _conflictCode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is Map<String, dynamic>) {
          return detail['code'] as String? ?? 'revision_conflict';
        }
      }
    } on FormatException {
      // Mantém um código seguro e não exibe conteúdo arbitrário do servidor.
    }
    return 'revision_conflict';
  }

  Future<AssessmentSyncRecord> _serialize(
    Future<AssessmentSyncRecord> Function() operation,
  ) {
    final completer = Completer<AssessmentSyncRecord>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Uri _uri(String path) {
    final base = apiUrl.endsWith('/')
        ? apiUrl.substring(0, apiUrl.length - 1)
        : apiUrl;
    return Uri.parse('$base$path');
  }

  List<String> _weakTopics(AssessmentDeck deck, Map<int, int> answers) =>
      Iterable<int>.generate(deck.items.length)
          .where((index) => answers[index] != deck.items[index].correctIndex)
          .map((index) => deck.items[index].topic)
          .toSet()
          .toList();

  void dispose() => _client.close();
}
