import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/study_ai_service.dart';
import '../models/study_models.dart';
import 'study_async_view.dart';
import 'study_material_controller.dart';

enum AssessmentMode { quiz, exam }

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key, required this.topic, required this.mode});

  final String topic;
  final AssessmentMode mode;

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final StudyMaterialController<AssessmentDeck> _controller =
      StudyMaterialController();
  StudyDifficulty _difficulty = StudyDifficulty.intermediate;
  final Map<int, int> _answers = {};
  int _index = 0;
  bool _finished = false;
  Timer? _timer;
  int _remainingSeconds = 0;

  bool get _isExam => widget.mode == AssessmentMode.exam;

  @override
  void dispose() {
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
          ? service.generateExam(topic: widget.topic, difficulty: _difficulty)
          : service.generateQuiz(topic: widget.topic, difficulty: _difficulty),
    );
    if (!mounted || !_isExam) return;
    final deck = _controller.state.data;
    if (deck != null) _startTimer(deck.durationMinutes);
  }

  void _startTimer(int minutes) {
    _remainingSeconds = minutes.clamp(1, 120) * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _finished = true;
        });
      } else {
        setState(() => _remainingSeconds--);
      }
    });
    setState(() {});
  }

  void _selectAnswer(int answer) {
    if (_answers.containsKey(_index)) return;
    setState(() => _answers[_index] = answer);
  }

  void _finish() {
    _timer?.cancel();
    setState(() => _finished = true);
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: SegmentedButton<StudyDifficulty>(
                segments: StudyDifficulty.values
                    .map(
                      (value) =>
                          ButtonSegment(value: value, label: Text(value.label)),
                    )
                    .toList(),
                selected: {_difficulty},
                onSelectionChanged: (selection) =>
                    setState(() => _difficulty = selection.first),
              ),
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
                  readyBuilder: _buildAssessment,
                ),
              ),
            ),
          ],
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
                Card.filled(
                  color: selected == question.correctIndex
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected == question.correctIndex
                              ? 'Resposta correta!'
                              : 'Vamos revisar',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(question.explanation),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  if (safeIndex > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _index--),
                      child: const Text('Anterior'),
                    ),
                  const Spacer(),
                  if (safeIndex < deck.items.length - 1)
                    FilledButton(
                      onPressed: selected == null
                          ? null
                          : () => setState(() => _index++),
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
