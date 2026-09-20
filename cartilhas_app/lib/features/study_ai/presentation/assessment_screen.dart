import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/assessment_attempt_repository.dart';
import '../data/study_ai_service.dart';
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
  });

  final String topic;
  final AssessmentMode mode;
  final String? courseId;
  final AssessmentAttemptRepository repository;
  final AssessmentAttempt? initialAttempt;

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
  int _index = 0;
  bool _finished = false;
  Timer? _timer;
  int _remainingSeconds = 0;
  AssessmentAttempt? _existingAttempt;
  AssessmentAttempt? _currentAttempt;
  Future<void> _saveQueue = Future<void>.value();

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
    _count = _isExam ? 10 : 5;
    if (widget.initialAttempt != null) {
      _existingAttempt = widget.initialAttempt;
      _restoreAttempt(widget.initialAttempt!);
    } else {
      _loadExistingAttempt();
    }
  }

  Future<void> _loadExistingAttempt() async {
    final attempt = await widget.repository.load(
      widget.resolvedCourseId,
      widget.mode,
    );
    if (mounted) {
      setState(() => _existingAttempt = attempt);
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
    _saveCurrentProgress();
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    _timer?.cancel();
    setState(() {
      _answers.clear();
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
        id: '${widget.resolvedCourseId}_${widget.mode.name}_${DateTime.now().millisecondsSinceEpoch}',
        courseId: widget.resolvedCourseId,
        topic: widget.topic,
        mode: widget.mode,
        difficulty: _difficulty,
        totalQuestions: deck.items.length,
        deck: deck,
        answers: const {},
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
    if (_answers.containsKey(_index)) return;
    setState(() => _answers[_index] = answer);
    _saveCurrentProgress();
  }

  void _saveCurrentProgress() {
    if (_currentAttempt == null) return;
    _currentAttempt = _currentAttempt!.copyWith(
      answers: Map.of(_answers),
      currentIndex: _index,
      remainingSeconds: _remainingSeconds,
      updatedAt: DateTime.now(),
    );
    _persistAttempt(_currentAttempt!);
  }

  void _persistAttempt(AssessmentAttempt attempt) {
    _saveQueue = _saveQueue.then((_) => widget.repository.save(attempt));
  }

  void _finish() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 0;
      _finished = true;
    });
    final deck = _controller.state.data;
    if (deck != null && _currentAttempt != null) {
      final correct = Iterable<int>.generate(deck.items.length)
          .where((index) => _answers[index] == deck.items[index].correctIndex)
          .length;
      final weakTopics = Iterable<int>.generate(deck.items.length)
          .where((index) => _answers[index] != deck.items[index].correctIndex)
          .map((index) => deck.items[index].topic)
          .toSet()
          .toList();
      _currentAttempt = _currentAttempt!.copyWith(
        answers: Map.of(_answers),
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
              const SizedBox(height: 20),
              Text(
                question.question,
                style: Theme.of(context).textTheme.headlineSmall,
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
                    correctIndex: _isExam || selected == null
                        ? null
                        : question.correctIndex,
                    onTap: () => _selectAnswer(optionIndex),
                  ),
                ),
              if (!_isExam && selected != null) ...[
                AssessmentFeedbackCard(
                  isCorrect: selected == question.correctIndex,
                  explanation: question.explanation,
                  source: widget.topic,
                  isLastQuestion: safeIndex == deck.items.length - 1,
                ),
                const SizedBox(height: 12),
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
                      onPressed: selected == null
                          ? null
                          : () {
                              setState(() => _index++);
                              _saveCurrentProgress();
                            },
                      child: const Text('Próxima'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: selected == null ? null : _finish,
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Ver resultado'),
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
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.index,
    required this.text,
    required this.selected,
    required this.correctIndex,
    required this.onTap,
  });

  final int index;
  final String text;
  final int? selected;
  final int? correctIndex;
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
        onTap: selected == null ? onTap : null,
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
