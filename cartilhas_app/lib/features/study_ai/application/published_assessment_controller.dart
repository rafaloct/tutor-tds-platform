import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../../models/cartilha.dart';
import '../data/assessment_attempt_repository.dart';
import '../data/assessment_sync_service.dart';
import '../models/assessment_sync_models.dart';
import '../models/study_models.dart';

@immutable
class PublishedAssessmentBlock {
  const PublishedAssessmentBlock({
    required this.courseId,
    required this.courseTitle,
    required this.section,
    required this.message,
    required this.context,
  });

  final String courseId;
  final String courseTitle;
  final Section section;
  final Message message;
  final PublishedAssessmentContext context;

  String get attemptId {
    final digest = sha256
        .convert(utf8.encode(context.canonicalAttemptDiscriminator))
        .toString();
    return 'attempt:published:${digest.substring(0, 48)}';
  }
}

/// Coordinates one immutable published block. Every user mutation is written
/// to the attempt store and durable assessment queue before the reader may move
/// to another block. Network delivery is deliberately asynchronous.
class PublishedAssessmentController extends ChangeNotifier {
  PublishedAssessmentController(this._store, this._sync);

  final PublishedAssessmentAttemptStore _store;
  final AssessmentSyncCoordinator _sync;

  PublishedAssessmentBlock? _block;
  AssessmentAttempt? _attempt;
  AssessmentSyncRecord? _syncRecord;
  bool _durablyRecorded = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  PublishedAssessmentBlock? get block => _block;
  AssessmentAttempt? get attempt => _attempt;
  AssessmentSyncRecord? get syncRecord => _syncRecord;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;
  int? get selectedOptionIndex => _attempt?.answers[0];
  bool get selectionReady => selectedOptionIndex != null && _durablyRecorded;
  bool get accessDenied => _authorizationDenied;
  bool get activityUnavailable => _hasPermanentRejection;
  bool get markedForReview =>
      _attempt?.reviewQuestionIndexes.contains(0) == true;
  bool get isCompleted => _attempt?.isCompleted == true;

  bool matches(PublishedAssessmentContext context) =>
      _block?.context.sameAs(context) == true;

  Future<void> open(PublishedAssessmentBlock block) async {
    _block = block;
    _attempt = null;
    _syncRecord = null;
    _durablyRecorded = false;
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      final local = await _store.loadPublished(block.context);
      if (local != null &&
          (local.id != block.attemptId ||
              local.courseId != block.courseId ||
              local.origin != AssessmentOrigin.publishedBlock ||
              local.publishedContext?.sameAs(block.context) != true)) {
        throw const FormatException(
          'A tentativa local não corresponde ao bloco publicado.',
        );
      }
      _attempt = local;
      if (local != null) {
        _syncRecord = await _sync.status(local.id);
        _durablyRecorded = _isDurable(_syncRecord);
        _showBlockingError(notify: false);
      }
      await _reconcileOwnedRemote(block, local);
      await _restoreMissingQueue();
    } on Object {
      _error = 'Não foi possível retomar esta atividade agora.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> selectOption(int optionIndex) async {
    final block = _requireBlock();
    final options = block.message.options ?? const <Option>[];
    if (optionIndex < 0 || optionIndex >= options.length) return false;
    if (_hasBlockingError) {
      _showBlockingError();
      return false;
    }
    final current = _attempt ?? _newAttempt(block);
    if (current.isCompleted) return false;
    return _persist(
      current.copyWith(
        answers: {0: optionIndex},
        currentIndex: 0,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<bool> toggleReview() async {
    final block = _requireBlock();
    if (_hasBlockingError) {
      _showBlockingError();
      return false;
    }
    final current = _attempt ?? _newAttempt(block);
    if (current.isCompleted) return false;
    final marked = Set<int>.from(current.reviewQuestionIndexes);
    marked.contains(0) ? marked.remove(0) : marked.add(0);
    return _persist(
      current.copyWith(
        reviewQuestionIndexes: marked,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<bool> complete() async {
    final current = _attempt;
    if (current == null || !current.answers.containsKey(0)) {
      _error = 'Escolha uma alternativa antes de continuar.';
      notifyListeners();
      return false;
    }
    if (_hasBlockingError) {
      _showBlockingError();
      return false;
    }
    if (current.isCompleted && _durablyRecorded) {
      return true;
    }
    if (_syncRecord?.status == AssessmentSyncStatus.conflict) {
      _error = 'Há outra revisão desta atividade. Reabra para reconciliar.';
      notifyListeners();
      return false;
    }
    return _persist(
      current.copyWith(
        isCompleted: true,
        remainingSeconds: 0,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<bool> retry() async {
    final current = _attempt;
    if (current == null) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final needsQueue = _syncRecord == null;
      _syncRecord = needsQueue
          ? await _sync.queueAttempt(current)
          : await _sync.retry(current.id);
      _durablyRecorded = _isDurable(_syncRecord);
      if (_syncRecord?.status == AssessmentSyncStatus.conflict) {
        _error = 'Há outra revisão desta atividade. Reabra para reconciliar.';
        return false;
      }
      if (_hasBlockingError) {
        _showBlockingError(notify: false);
        return false;
      }
      if (!_durablyRecorded) {
        _error = 'A atividade continua salva neste aparelho. Tente novamente.';
        return false;
      }
      if (needsQueue) unawaited(_deliver(current.id));
      return true;
    } on Object {
      _error = 'A atividade continua salva neste aparelho. Tente novamente.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> _persist(AssessmentAttempt next) async {
    if (_saving) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _store.saveConfirmed(next);
      _attempt = next;
      _syncRecord = null;
      _durablyRecorded = false;
      notifyListeners();
      _syncRecord = await _sync.queueAttempt(next);
      _durablyRecorded = _isDurable(_syncRecord);
      if (_syncRecord?.status == AssessmentSyncStatus.conflict) {
        _error = 'Há outra revisão desta atividade. Reabra para reconciliar.';
        return false;
      }
      if (_hasBlockingError) {
        _showBlockingError(notify: false);
        return false;
      }
      if (!_durablyRecorded) {
        _error =
            'A resposta está salva, mas o envio precisa ser tentado novamente.';
        return false;
      }
      unawaited(_deliver(next.id));
      return true;
    } on Object {
      _error = _attempt == next
          ? 'A resposta está salva, mas o envio precisa ser tentado novamente.'
          : 'Não foi possível salvar a resposta. Tente novamente.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> _deliver(String attemptId) async {
    try {
      final record = await _sync.retry(attemptId);
      if (_attempt?.id != attemptId) return;
      _syncRecord = record;
      _durablyRecorded = _isDurable(record);
      if (record.status == AssessmentSyncStatus.conflict) {
        _error = 'Há outra revisão desta atividade. Reabra para reconciliar.';
      } else if (_hasBlockingError) {
        _showBlockingError(notify: false);
      }
      notifyListeners();
    } on Object {
      // The durable local queue is the user-visible guarantee while offline.
    }
  }

  Future<void> _reconcileOwnedRemote(
    PublishedAssessmentBlock block,
    AssessmentAttempt? local,
  ) async {
    final publishedSync = _sync;
    if (publishedSync is! PublishedAssessmentSyncCoordinator) return;
    final matching = await (publishedSync as PublishedAssessmentSyncCoordinator)
        .findPublishedAttempt(block.context, block.attemptId);
    if (matching == null) return;
    if (local == null || matching.payload.completed) {
      final hydrated = await _sync.hydrateRemoteAttempt(matching);
      if (hydrated.publishedContext?.sameAs(block.context) != true) {
        throw const FormatException('Contexto remoto divergente.');
      }
      await _store.saveConfirmed(hydrated);
      _attempt = hydrated;
      _syncRecord = await _sync.status(hydrated.id);
      _durablyRecorded = true;
      return;
    }
    _syncRecord = await _sync.registerDiscovered(local, matching);
    _durablyRecorded = _isDurable(_syncRecord);
    if (_syncRecord?.status == AssessmentSyncStatus.conflict) {
      _error = 'Há duas revisões desta atividade; nenhuma foi sobrescrita.';
    } else if (_hasBlockingError) {
      _showBlockingError(notify: false);
    }
  }

  Future<void> _restoreMissingQueue() async {
    final current = _attempt;
    if (current == null || _syncRecord != null || _durablyRecorded) return;
    try {
      _syncRecord = await _sync.queueAttempt(current);
      _durablyRecorded = _isDurable(_syncRecord);
      if (_syncRecord?.status == AssessmentSyncStatus.conflict) {
        _error = 'Há outra revisão desta atividade. Reabra para reconciliar.';
        return;
      }
      if (_hasBlockingError) {
        _showBlockingError(notify: false);
        return;
      }
      if (!_durablyRecorded) {
        _error = 'A atividade está salva neste aparelho. Tente novamente.';
        return;
      }
      unawaited(_deliver(current.id));
    } on Object {
      _durablyRecorded = false;
      _error = 'A atividade está salva neste aparelho. Tente novamente.';
    }
  }

  AssessmentAttempt _newAttempt(PublishedAssessmentBlock block) {
    final now = DateTime.now().toUtc();
    final options = block.message.options ?? const <Option>[];
    return AssessmentAttempt(
      id: block.attemptId,
      assessmentContentId: null,
      origin: AssessmentOrigin.publishedBlock,
      publishedContext: block.context,
      courseId: block.courseId,
      topic: block.section.title,
      mode: AssessmentMode.quiz,
      difficulty: StudyDifficulty.intermediate,
      totalQuestions: 1,
      deck: AssessmentDeck(
        title: '${block.courseTitle} • ${block.section.title}',
        durationMinutes: 0,
        items: [
          StudyQuestion(
            question: block.message.content,
            options: options.map((option) => option.label).toList(),
            // The answer key belongs to the immutable server snapshot.
            correctIndex: -1,
            correctIndexes: const {},
            graded: false,
            explanation:
                block.message.explanation ?? block.message.feedback ?? '',
            topic: block.section.title,
          ),
        ],
      ),
      answers: const {},
      currentIndex: 0,
      remainingSeconds: 0,
      score: 0,
      weakTopics: const [],
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  PublishedAssessmentBlock _requireBlock() {
    final current = _block;
    if (current == null) throw StateError('Nenhum bloco publicado foi aberto.');
    return current;
  }

  bool _isDurable(AssessmentSyncRecord? record) =>
      (record?.status == AssessmentSyncStatus.pending &&
          !_isAuthorizationDenied(record) &&
          !_isPermanentRejection(record)) ||
      record?.status == AssessmentSyncStatus.synced;

  bool get _authorizationDenied => _isAuthorizationDenied(_syncRecord);
  bool get _hasPermanentRejection => _isPermanentRejection(_syncRecord);
  bool get _hasBlockingError => _authorizationDenied || _hasPermanentRejection;

  bool _isAuthorizationDenied(AssessmentSyncRecord? record) =>
      record?.lastError == 'active_enrollment_required';

  bool _isPermanentRejection(AssessmentSyncRecord? record) {
    if (record?.status != AssessmentSyncStatus.pending) return false;
    final error = record?.lastError;
    if (error == null ||
        error == 'active_enrollment_required' ||
        error == 'network_unavailable' ||
        error == 'api_unavailable' ||
        error == 'session_required' ||
        error == 'session_unavailable') {
      return false;
    }
    final serverStatus = RegExp(r'^server_(\d{3})$').firstMatch(error);
    if (serverStatus != null) {
      final status = int.parse(serverStatus.group(1)!);
      return status != 408 && status != 429 && status < 500;
    }
    return true;
  }

  void _showBlockingError({bool notify = true}) {
    if (_authorizationDenied) {
      _showAuthorizationDenied(notify: notify);
    } else if (_hasPermanentRejection) {
      _durablyRecorded = false;
      _error =
          'Esta atividade ainda não está disponível neste ambiente. Tente novamente após a liberação.';
      if (notify) notifyListeners();
    }
  }

  void _showAuthorizationDenied({bool notify = true}) {
    _durablyRecorded = false;
    _error =
        'Seu acesso a esta turma não está ativo. Atualize a matrícula antes de continuar.';
    if (notify) notifyListeners();
  }
}
