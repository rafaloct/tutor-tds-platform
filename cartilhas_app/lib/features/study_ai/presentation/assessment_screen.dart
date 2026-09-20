import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../../screens/genui_assistant_screen.dart';
import '../data/assessment_attempt_repository.dart';
import '../data/assessment_sync_service.dart';
import '../data/study_ai_service.dart';
import '../models/assessment_sync_models.dart';
import '../models/study_models.dart';
import 'assessment_feedback_card.dart';
import 'study_async_view.dart';
import 'study_generation_controls.dart';
import 'study_material_controller.dart';

export '../models/study_models.dart' show AssessmentMode;

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({
    super.key,
    required this.topic,
    required this.mode,
    this.courseId,
    this.repository = const AssessmentAttemptRepository(),
    this.initialAttempt,
    this.syncCoordinator,
  });

  final String topic;
  final AssessmentMode mode;
  final String? courseId;
  final AssessmentAttemptRepository repository;
  final AssessmentAttempt? initialAttempt;
  final AssessmentSyncCoordinator? syncCoordinator;

  String get resolvedCourseId => courseId ?? topic;

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final StudyMaterialController<AssessmentDeck> _controller =
      StudyMaterialController();
  StudyDifficulty _difficulty = StudyDifficulty.intermediate;
  late int _count;
  final Map<int, int> _answers = {};
  final Set<int> _markedForReview = {};
  final FlutterTts _tts = FlutterTts();
  int _index = 0;
  bool _finished = false;
  Timer? _timer;
  int _remainingSeconds = 0;
  AssessmentAttempt? _existingAttempt;
  AssessmentAttempt? _currentAttempt;
  Future<void> _saveQueue = Future<void>.value();
  bool _isSaving = false;
  bool _largeQuestionText = false;
  bool _isRetryingSync = false;
  AssessmentSyncCoordinator? _syncCoordinator;
  AssessmentSyncRecord? _syncRecord;
  RemoteAssessmentAttempt? _remoteAttemptWithoutContent;
  String? _remoteRecoveryMessage;
  bool _didResolveSyncCoordinator = false;
  bool _didDiscoverRemote = false;
  bool _localLoadComplete = false;

  bool get _isExam => widget.mode == AssessmentMode.exam;

  List<int> get _countOptions {
    final options = <int>{
      ...(_isExam ? const [10, 15, 20] : const [5, 8, 10]),
      _count,
    }.toList()..sort();
    return options;
  }

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('pt-BR');
    _tts.setSpeechRate(0.5);
    _count = _isExam ? 10 : 5;
    if (widget.initialAttempt != null) {
      _existingAttempt = widget.initialAttempt;
      _restoreAttempt(widget.initialAttempt!);
    } else {
      _loadExistingAttempt();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didResolveSyncCoordinator) return;
    _didResolveSyncCoordinator = true;
    _syncCoordinator =
        widget.syncCoordinator ?? context.read<AssessmentSyncCoordinator?>();
    final attempt = _currentAttempt ?? _existingAttempt;
    if (attempt != null || _localLoadComplete) {
      _initializeRemoteState(attempt);
    }
  }

  Future<void> _loadExistingAttempt() async {
    final attempt = await widget.repository.load(
      widget.resolvedCourseId,
      widget.mode,
    );
    if (mounted) {
      setState(() {
        _existingAttempt = attempt;
        _localLoadComplete = true;
      });
      await _initializeRemoteState(attempt);
    }
  }

  void _restoreAttempt(AssessmentAttempt attempt) {
    _timer?.cancel();
    setState(() {
      _currentAttempt = attempt;
      _difficulty = attempt.difficulty;
      _count = attempt.totalQuestions;
      _answers.clear();
      _answers.addAll(attempt.answers);
      _markedForReview
        ..clear()
        ..addAll(attempt.reviewQuestionIndexes);
      _index = attempt.currentIndex.clamp(
        0,
        (attempt.deck.items.length - 1).clamp(0, 9999),
      );
      _finished = attempt.isCompleted;
      _remainingSeconds = attempt.remainingSeconds;
    });
    _controller.setData(attempt.deck);
    if (!attempt.isCompleted && _isExam && _remainingSeconds > 0) {
      _resumeTimer();
    }
    _syncSavedAttempt(attempt);
  }

  void _resumeTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _finish();
      } else {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds % 10 == 0) {
          _saveCurrentProgress();
        }
      }
    });
  }

  @override
  void dispose() {
    final attempt = _currentAttempt;
    if (attempt != null) {
      final finalAttempt = attempt.copyWith(
        answers: Map.of(_answers),
        reviewQuestionIndexes: Set.of(_markedForReview),
        currentIndex: _index,
        remainingSeconds: _remainingSeconds,
        updatedAt: DateTime.now(),
      );
      unawaited(
        widget.repository.save(finalAttempt).then((_) async {
          await _syncCoordinator?.queueAttempt(finalAttempt);
        }),
      );
    }
    _timer?.cancel();
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    _timer?.cancel();
    setState(() {
      _answers.clear();
      _markedForReview.clear();
      _index = 0;
      _finished = false;
      _remainingSeconds = 0;
    });
    final service = context.read<StudyAiService>();
    await _controller.generate(
      () => _isExam
          ? service.generateExam(
              topic: widget.topic,
              difficulty: _difficulty,
              count: _count,
            )
          : service.generateQuiz(
              topic: widget.topic,
              difficulty: _difficulty,
              count: _count,
            ),
    );
    if (!mounted) return;
    final deck = _controller.state.data;
    if (deck != null) {
      final attempt = AssessmentAttempt(
        id: 'assessment_${widget.mode.name}_${DateTime.now().microsecondsSinceEpoch}',
        courseId: widget.resolvedCourseId,
        topic: widget.topic,
        mode: widget.mode,
        difficulty: _difficulty,
        totalQuestions: deck.items.length,
        deck: deck,
        answers: const {},
        reviewQuestionIndexes: const {},
        currentIndex: 0,
        remainingSeconds: _isExam ? deck.durationMinutes.clamp(1, 120) * 60 : 0,
        score: 0,
        weakTopics: const [],
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _currentAttempt = attempt;
      _existingAttempt = attempt;
      await widget.repository.save(attempt);
      final coordinator = _syncCoordinator;
      if (coordinator != null) {
        final record = await coordinator.queueAndSync(attempt);
        if (mounted) setState(() => _syncRecord = record);
      }
      if (_isExam) {
        _startTimer(deck.durationMinutes);
      }
    }
  }

  void _startTimer(int minutes) {
    _remainingSeconds = minutes.clamp(1, 120) * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _finish();
      } else {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds % 10 == 0) {
          _saveCurrentProgress();
        }
      }
    });
    setState(() {});
  }

  void _selectAnswer(int answer) {
    final hasAnswerKey = _controller.state.data?.hasAnswerKey ?? false;
    if (!_isExam && hasAnswerKey && _answers.containsKey(_index)) return;
    setState(() => _answers[_index] = answer);
    _saveCurrentProgress();
  }

  void _saveCurrentProgress() {
    if (_currentAttempt == null) return;
    _currentAttempt = _currentAttempt!.copyWith(
      answers: Map.of(_answers),
      reviewQuestionIndexes: Set.of(_markedForReview),
      currentIndex: _index,
      remainingSeconds: _remainingSeconds,
      updatedAt: DateTime.now(),
    );
    _persistAttempt(_currentAttempt!);
  }

  void _persistAttempt(AssessmentAttempt attempt) {
    if (mounted) setState(() => _isSaving = true);
    _saveQueue = _saveQueue.then((_) async {
      await widget.repository.save(attempt);
      final coordinator = _syncCoordinator;
      AssessmentSyncRecord? record;
      if (coordinator != null) {
        record = await coordinator.queueAndSync(attempt);
      }
      AssessmentAttempt? hydrated;
      final confirmed = record?.confirmedPayload;
      if (attempt.isCompleted &&
          !attempt.deck.hasAnswerKey &&
          record?.status == AssessmentSyncStatus.synced &&
          confirmed != null) {
        try {
          hydrated = await coordinator?.hydrateRemoteAttempt(
            RemoteAssessmentAttempt(attemptId: attempt.id, payload: confirmed),
          );
          if (hydrated != null) await widget.repository.save(hydrated);
        } on AssessmentSyncConflictException {
          // A entrega local continua segura; o gabarito poderá ser recuperado.
        }
      }
      if (mounted) {
        setState(() {
          _isSaving = false;
          _syncRecord = record;
          if (hydrated != null) {
            _currentAttempt = hydrated;
            _existingAttempt = hydrated;
            _answers
              ..clear()
              ..addAll(hydrated.answers);
          }
        });
        if (hydrated != null) _controller.setData(hydrated.deck);
      }
    });
  }

  Future<void> _refreshSyncStatus(String attemptId) async {
    final coordinator = _syncCoordinator;
    if (coordinator == null) return;
    final record = await coordinator.status(attemptId);
    if (mounted && (_currentAttempt ?? _existingAttempt)?.id == attemptId) {
      setState(() => _syncRecord = record);
    }
  }

  Future<void> _syncSavedAttempt(AssessmentAttempt attempt) async {
    final coordinator = _syncCoordinator;
    if (coordinator == null) return;
    final record = await coordinator.queueAndSync(attempt);
    if (mounted && (_currentAttempt ?? _existingAttempt)?.id == attempt.id) {
      setState(() => _syncRecord = record);
    }
  }

  Future<void> _initializeRemoteState(AssessmentAttempt? local) async {
    final coordinator = _syncCoordinator;
    if (coordinator == null || _didDiscoverRemote) {
      if (local != null) await _syncSavedAttempt(local);
      return;
    }
    _didDiscoverRemote = true;
    final remote = await coordinator.discoverIncomplete(
      courseId: widget.resolvedCourseId,
      mode: widget.mode,
    );
    if (!mounted) return;
    if (local == null) {
      if (remote.isEmpty) return;
      final candidate = remote.first;
      try {
        final hydrated = await coordinator.hydrateRemoteAttempt(candidate);
        await widget.repository.save(hydrated);
        if (!mounted) return;
        setState(() {
          _existingAttempt = hydrated;
          _remoteAttemptWithoutContent = null;
          _remoteRecoveryMessage = null;
        });
      } on AssessmentLegacyContentException catch (error) {
        if (!mounted) return;
        setState(() {
          _remoteAttemptWithoutContent = candidate;
          _remoteRecoveryMessage = error.message;
        });
      } on AssessmentSyncConflictException catch (error) {
        if (!mounted) return;
        setState(() {
          _remoteAttemptWithoutContent = candidate;
          _remoteRecoveryMessage = error.message;
        });
      }
      return;
    }
    RemoteAssessmentAttempt? matching;
    for (final candidate in remote) {
      if (candidate.attemptId == local.id) {
        matching = candidate;
        break;
      }
    }
    if (matching != null) {
      try {
        final record = await coordinator.registerDiscovered(local, matching);
        if (mounted) setState(() => _syncRecord = record);
      } on AssessmentSyncConflictException {
        // Mantém o autosave local íntegro; a sincronização comum seguirá segura.
      }
    }
    await _syncSavedAttempt(local);
  }

  AssessmentSyncStatus get _syncStatus =>
      _syncRecord?.status ?? AssessmentSyncStatus.localOnly;

  bool get _needsActiveEnrollment =>
      _syncRecord?.lastError == 'active_enrollment_required';

  String get _syncLabel => _needsActiveEnrollment
      ? 'Tentativa segura neste aparelho • matrícula ativa necessária para sincronizar'
      : _syncStatus.label;

  Future<void> _retrySync() async {
    final attempt = _currentAttempt;
    final coordinator = _syncCoordinator;
    if (attempt == null || coordinator == null || _isRetryingSync) return;
    setState(() => _isRetryingSync = true);
    try {
      final record = await coordinator.retry(attempt.id);
      AssessmentAttempt? hydrated;
      final confirmed = record.confirmedPayload;
      if (attempt.isCompleted &&
          !attempt.deck.hasAnswerKey &&
          record.status == AssessmentSyncStatus.synced &&
          confirmed != null) {
        try {
          hydrated = await coordinator.hydrateRemoteAttempt(
            RemoteAssessmentAttempt(attemptId: attempt.id, payload: confirmed),
          );
          await widget.repository.save(hydrated);
        } on AssessmentSyncConflictException {
          // Mantém a entrega confirmada e permite nova recuperação manual.
        }
      }
      if (mounted) {
        setState(() {
          _syncRecord = record;
          if (hydrated != null) {
            _currentAttempt = hydrated;
            _existingAttempt = hydrated;
            _answers
              ..clear()
              ..addAll(hydrated.answers);
          }
        });
        if (hydrated != null) _controller.setData(hydrated.deck);
      }
    } finally {
      if (mounted) setState(() => _isRetryingSync = false);
    }
  }

  Future<void> _resolveConflict() async {
    final attempt = _currentAttempt;
    final coordinator = _syncCoordinator;
    if (attempt == null || coordinator == null) return;
    var remote = _syncRecord?.remoteConflict;
    if (remote == null) {
      final refreshed = await coordinator.refreshConflict(attempt.id);
      if (!mounted) return;
      setState(() => _syncRecord = refreshed);
      remote = refreshed.remoteConflict;
    }
    if (remote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A versão do servidor ainda não está disponível. Seu progresso local foi preservado.',
          ),
        ),
      );
      return;
    }
    final resolvedRemote = remote;
    final choice = await showDialog<_ConflictChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escolha como continuar'),
        content: Text(
          'Há duas versões desta tentativa. A versão online está na revisão '
          '${resolvedRemote.payload.revision}. Nenhuma resposta será substituída sem sua escolha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Agora não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ConflictChoice.useRemote),
            child: const Text('Usar versão online'),
          ),
          FilledButton(
            onPressed: resolvedRemote.payload.completed
                ? null
                : () => Navigator.pop(context, _ConflictChoice.keepLocal),
            child: const Text('Manter deste aparelho'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    try {
      if (choice == _ConflictChoice.useRemote) {
        final merged = await coordinator.resolveUsingRemote(attempt);
        await widget.repository.save(merged);
        if (!mounted) return;
        _existingAttempt = merged;
        _restoreAttempt(merged);
        await _refreshSyncStatus(merged.id);
      } else {
        final record = await coordinator.resolveKeepingLocal(attempt);
        if (mounted) setState(() => _syncRecord = record);
      }
    } on AssessmentSyncConflictException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _finish() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 0;
      _finished = true;
    });
    final deck = _controller.state.data;
    if (deck != null && _currentAttempt != null) {
      final correct = deck.hasAnswerKey
          ? Iterable<int>.generate(deck.items.length)
                .where(
                  (index) => _answers[index] == deck.items[index].correctIndex,
                )
                .length
          : 0;
      final weakTopics = deck.hasAnswerKey
          ? Iterable<int>.generate(deck.items.length)
                .where(
                  (index) => _answers[index] != deck.items[index].correctIndex,
                )
                .map((index) => deck.items[index].topic)
                .toSet()
                .toList()
          : <String>[];
      _currentAttempt = _currentAttempt!.copyWith(
        answers: Map.of(_answers),
        reviewQuestionIndexes: Set.of(_markedForReview),
        currentIndex: _index,
        remainingSeconds: 0,
        score: correct,
        weakTopics: weakTopics,
        isCompleted: true,
        updatedAt: DateTime.now(),
      );
      _existingAttempt = _currentAttempt;
      _persistAttempt(_currentAttempt!);
    }
  }

  Future<void> _requestFinish(AssessmentDeck deck) async {
    if (!_isExam) {
      _finish();
      return;
    }
    final unanswered = deck.items.length - _answers.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entregar simulado?'),
        content: Text(
          unanswered == 0
              ? 'Suas respostas estão salvas neste aparelho. Depois da entrega, elas não poderão ser alteradas.'
              : 'Ainda há $unanswered questão(ões) sem resposta. Você pode voltar e concluir antes da entrega.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(unanswered == 0 ? 'Cancelar' : 'Voltar e revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(unanswered == 0 ? 'Entregar' : 'Entregar assim mesmo'),
          ),
        ],
      ),
    );
    if (confirmed == true) _finish();
  }

  void _toggleReview() {
    setState(() {
      if (!_markedForReview.add(_index)) _markedForReview.remove(_index);
    });
    _saveCurrentProgress();
  }

  Future<void> _speakQuestion(StudyQuestion question) async {
    await _tts.stop();
    await _tts.speak('${question.question}. ${question.options.join('. ')}');
  }

  void _askTutor(StudyQuestion question) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GenUIAssistantScreen(
          contextLabel: widget.topic,
          initialContext:
              'Ajude a revisar esta questão: ${question.question}. Explicação disponível: ${question.explanation}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isExam ? 'Simulado com IA' : 'Quiz com IA';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isExam && _remainingSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Chip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(_formatTime(_remainingSeconds)),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            StudyConfigurationPanel(
              source: widget.topic,
              controls: [
                SegmentedButton<StudyDifficulty>(
                  segments: StudyDifficulty.values
                      .map(
                        (value) => ButtonSegment(
                          value: value,
                          label: Text(value.label),
                        ),
                      )
                      .toList(),
                  selected: {_difficulty},
                  onSelectionChanged: (selection) =>
                      setState(() => _difficulty = selection.first),
                ),
                StudyCountSelector(
                  value: _count,
                  options: _countOptions,
                  onChanged: (value) => setState(() => _count = value),
                  label: 'Questões',
                ),
              ],
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => StudyAsyncView<AssessmentDeck>(
                  state: _controller.state,
                  onGenerate: _generate,
                  idleTitle: _isExam
                      ? 'Prepare-se com um simulado'
                      : 'Pratique com um quiz',
                  idleDescription: _isExam
                      ? 'Responda no tempo indicado e descubra os temas que precisam de mais revisão.'
                      : 'Receba correção e explicação logo após cada resposta.',
                  generateLabel: _isExam ? 'Iniciar simulado' : 'Gerar quiz',
                  idleBuilder: _buildIdle,
                  readyBuilder: _buildAssessment,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    final existing = _existingAttempt;
    if (existing != null) {
      if (!existing.isCompleted) {
        final answeredCount = existing.answers.length;
        final total = existing.totalQuestions;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.pending_actions_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tentativa em andamento',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Chip(
                                label: Text(existing.difficulty.label),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$answeredCount de $total questões respondidas. Você pode retomar de onde parou sem nova chamada de IA.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: total > 0
                                ? (answeredCount / total).clamp(0, 1)
                                : 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _restoreAttempt(existing),
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: Text(
                        'Retomar ${_isExam ? "simulado" : "quiz"} em andamento',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(
                        'Iniciar nov${_isExam ? "o simulado" : "o quiz"}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        final percent = existing.totalQuestions > 0
            ? ((existing.score / existing.totalQuestions) * 100).round()
            : 0;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Último resultado concluído',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Chip(
                                label: Text('$percent%'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${existing.score} de ${existing.totalQuestions} acertos na dificuldade ${existing.difficulty.label.toLowerCase()}.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(_isExam ? 'Iniciar simulado' : 'Gerar quiz'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _restoreAttempt(existing),
                      icon: const Icon(Icons.history),
                      label: const Text('Ver resultado anterior'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    final remote = _remoteAttemptWithoutContent;
    if (remote != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tentativa online encontrada',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _remoteRecoveryMessage ??
                          'Não foi possível recuperar as questões agora. Seu progresso online foi preservado.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${remote.payload.answers.length} resposta(s) salva(s) • revisão ${remote.payload.revision}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _didDiscoverRemote = false;
                          _remoteAttemptWithoutContent = null;
                          _remoteRecoveryMessage = null;
                        });
                        _initializeRemoteState(null);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar recuperar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                _isExam ? 'Prepare-se com um simulado' : 'Pratique com um quiz',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _isExam
                    ? 'Responda no tempo indicado e descubra os temas que precisam de mais revisão.'
                    : 'Receba correção e explicação logo após cada resposta.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_isExam ? 'Iniciar simulado' : 'Gerar quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessment(BuildContext context, AssessmentDeck deck) {
    if (deck.items.isEmpty) {
      return const Center(child: Text('Nenhuma questão foi gerada.'));
    }
    if (_finished) return _buildResult(context, deck);
    final safeIndex = _index.clamp(0, deck.items.length - 1);
    final question = deck.items[safeIndex];
    final selected = _answers[safeIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deck.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text('${safeIndex + 1}/${deck.items.length}'),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (safeIndex + 1) / deck.items.length,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    _isSaving ? Icons.save_outlined : _syncIcon(_syncStatus),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _isSaving ? 'Salvando neste aparelho...' : _syncLabel,
                      key: const ValueKey('assessment-sync-status'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  if (_syncStatus == AssessmentSyncStatus.conflict)
                    TextButton(
                      onPressed: _resolveConflict,
                      child: const Text('Resolver'),
                    ),
                  if (_needsActiveEnrollment)
                    TextButton(
                      onPressed: _isRetryingSync ? null : _retrySync,
                      child: Text(
                        _isRetryingSync ? 'Verificando...' : 'Tentar novamente',
                      ),
                    ),
                  if (_isExam) ...[
                    IconButton(
                      tooltip: 'Ouvir questão e alternativas',
                      onPressed: () => _speakQuestion(question),
                      icon: const Icon(Icons.volume_up_outlined),
                    ),
                    IconButton(
                      tooltip: _largeQuestionText
                          ? 'Usar texto normal'
                          : 'Aumentar texto',
                      onPressed: () => setState(
                        () => _largeQuestionText = !_largeQuestionText,
                      ),
                      icon: const Icon(Icons.text_increase),
                    ),
                  ],
                ],
              ),
              if (_isExam) ...[
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: deck.items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, questionIndex) => Semantics(
                      label:
                          'Questão ${questionIndex + 1}, ${_answers.containsKey(questionIndex) ? "respondida" : "sem resposta"}${_markedForReview.contains(questionIndex) ? ", marcada para revisar" : ""}',
                      child: ChoiceChip(
                        selected: questionIndex == safeIndex,
                        avatar: _markedForReview.contains(questionIndex)
                            ? const Icon(Icons.flag_outlined, size: 16)
                            : _answers.containsKey(questionIndex)
                            ? const Icon(Icons.check, size: 16)
                            : null,
                        label: Text('${questionIndex + 1}'),
                        onSelected: (_) {
                          setState(() => _index = questionIndex);
                          _saveCurrentProgress();
                        },
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                question.question,
                style: _largeQuestionText
                    ? Theme.of(context).textTheme.headlineMedium
                    : Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 18),
              for (
                var optionIndex = 0;
                optionIndex < question.options.length;
                optionIndex++
              )
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AnswerOption(
                    index: optionIndex,
                    text: question.options[optionIndex],
                    selected: selected,
                    correctIndex:
                        _isExam || selected == null || !deck.hasAnswerKey
                        ? null
                        : question.correctIndex,
                    locked: !_isExam && deck.hasAnswerKey && selected != null,
                    onTap: () => _selectAnswer(optionIndex),
                  ),
                ),
              if (!_isExam && selected != null && deck.hasAnswerKey) ...[
                AssessmentFeedbackCard(
                  isCorrect: selected == question.correctIndex,
                  explanation: question.explanation,
                  source: widget.topic,
                  isLastQuestion: safeIndex == deck.items.length - 1,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: Icon(
                        _markedForReview.contains(safeIndex)
                            ? Icons.flag
                            : Icons.flag_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _markedForReview.contains(safeIndex)
                            ? 'Marcada para rever'
                            : 'Refazer depois',
                      ),
                      onPressed: _toggleReview,
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.forum_outlined, size: 18),
                      label: const Text('Perguntar ao Tutor'),
                      onPressed: () => _askTutor(question),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (_isExam) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _toggleReview,
                    icon: Icon(
                      _markedForReview.contains(safeIndex)
                          ? Icons.flag
                          : Icons.flag_outlined,
                    ),
                    label: Text(
                      _markedForReview.contains(safeIndex)
                          ? 'Remover marca de revisão'
                          : 'Marcar para revisar',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (safeIndex > 0)
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _index--);
                        _saveCurrentProgress();
                      },
                      child: const Text('Anterior'),
                    ),
                  const Spacer(),
                  if (safeIndex < deck.items.length - 1)
                    FilledButton(
                      onPressed: !_isExam && selected == null
                          ? null
                          : () {
                              setState(() => _index++);
                              _saveCurrentProgress();
                            },
                      child: const Text('Próxima'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _isExam
                          ? () => _requestFinish(deck)
                          : selected == null
                          ? null
                          : () => _requestFinish(deck),
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(
                        _isExam ? 'Revisar e entregar' : 'Ver resultado',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, AssessmentDeck deck) {
    if (!deck.hasAnswerKey) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Entrega salva com segurança',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _syncStatus == AssessmentSyncStatus.synced
                          ? 'A entrega foi confirmada. Estamos recuperando o resultado validado pelo servidor.'
                          : 'As respostas permanecem neste aparelho. O resultado e o gabarito serão exibidos após a sincronização confirmada.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(_syncLabel, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isRetryingSync ? null : _retrySync,
                      icon: const Icon(Icons.sync),
                      label: Text(
                        _isRetryingSync
                            ? 'Verificando...'
                            : _syncStatus == AssessmentSyncStatus.synced
                            ? 'Recuperar resultado'
                            : 'Tentar sincronizar',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final correct = Iterable<int>.generate(deck.items.length)
        .where((index) => _answers[index] == deck.items[index].correctIndex)
        .length;
    final percent = ((correct / deck.items.length) * 100).round();
    final weakTopics = Iterable<int>.generate(deck.items.length)
        .where((index) => _answers[index] != deck.items[index].correctIndex)
        .map((index) => deck.items[index].topic)
        .toSet()
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              Icon(
                percent >= 70 ? Icons.emoji_events : Icons.insights_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                '$percent%',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text('$correct de ${deck.items.length} respostas corretas'),
              const SizedBox(height: 20),
              if (weakTopics.isNotEmpty)
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Temas para revisar',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        for (final topic in weakTopics)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.bookmark_outline),
                            title: Text(topic),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Card.outlined(
                child: ExpansionTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: const Text('Revisar respostas'),
                  subtitle: Text(
                    '${_answers.length} respondidas de ${deck.items.length}',
                  ),
                  children: [
                    for (var index = 0; index < deck.items.length; index++)
                      ListTile(
                        isThreeLine: true,
                        leading: Icon(
                          _answers[index] == deck.items[index].correctIndex
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                        ),
                        title: Text(
                          '${index + 1}. ${deck.items[index].question}',
                        ),
                        subtitle: Text(
                          _answers[index] == null
                              ? 'Sem resposta. Correta: ${deck.items[index].options[deck.items[index].correctIndex]}'
                              : 'Sua resposta: ${deck.items[index].options[_answers[index]!]}. '
                                    'Correta: ${deck.items[index].options[deck.items[index].correctIndex]}.\n'
                                    '${deck.items[index].explanation}',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: Text(_isExam ? 'Novo simulado' : 'Novo quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  IconData _syncIcon(AssessmentSyncStatus status) => switch (status) {
    AssessmentSyncStatus.localOnly => Icons.phone_android_outlined,
    AssessmentSyncStatus.pending => Icons.cloud_upload_outlined,
    AssessmentSyncStatus.synced => Icons.cloud_done_outlined,
    AssessmentSyncStatus.conflict => Icons.sync_problem_outlined,
  };
}

enum _ConflictChoice { useRemote, keepLocal }

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.index,
    required this.text,
    required this.selected,
    required this.correctIndex,
    required this.locked,
    required this.onTap,
  });

  final int index;
  final String text;
  final int? selected;
  final int? correctIndex;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == index;
    final isCorrect = correctIndex == index;
    final isIncorrect = isSelected && correctIndex != null && !isCorrect;
    final colors = Theme.of(context).colorScheme;
    final background = isCorrect
        ? colors.primaryContainer
        : isIncorrect
        ? colors.errorContainer
        : isSelected
        ? colors.secondaryContainer
        : colors.surfaceContainerLow;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                child: Text(String.fromCharCode(65 + index)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
              if (isCorrect) const Icon(Icons.check_circle_outline),
              if (isIncorrect) const Icon(Icons.cancel_outlined),
            ],
          ),
        ),
      ),
    );
  }
}
