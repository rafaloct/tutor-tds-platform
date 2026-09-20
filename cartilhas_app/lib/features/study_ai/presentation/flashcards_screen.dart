import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../data/study_ai_service.dart';
import '../models/study_models.dart';
import 'flashcard_review_status.dart';
import 'study_async_view.dart';
import 'study_generation_controls.dart';
import 'study_material_controller.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key, required this.topic});

  final String topic;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final StudyMaterialController<FlashcardDeck> _controller =
      StudyMaterialController();
  StudyDifficulty _difficulty = StudyDifficulty.intermediate;
  int _count = 8;
  int _index = 0;
  bool _showBack = false;
  final Set<int> _difficult = {};
  final Set<int> _remembered = {};
  final Map<int, _RecallRating> _ratings = {};
  final FlutterTts _tts = FlutterTts();
  bool _sessionComplete = false;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('pt-BR');
    _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  void _generate() {
    setState(() {
      _index = 0;
      _showBack = false;
      _difficult.clear();
      _remembered.clear();
      _ratings.clear();
      _sessionComplete = false;
    });
    _controller.generate(
      () => context.read<StudyAiService>().generateFlashcards(
        topic: widget.topic,
        difficulty: _difficulty,
        count: _count,
      ),
    );
  }

  void _rate(_RecallRating rating, int length) {
    setState(() {
      _ratings[_index] = rating;
      if (rating == _RecallRating.forgot || rating == _RecallRating.difficult) {
        _difficult.add(_index);
        _remembered.remove(_index);
      } else {
        _difficult.remove(_index);
        _remembered.add(_index);
      }
      if (_ratings.length >= length) {
        _sessionComplete = true;
      } else {
        _index = (_index + 1) % length;
        while (_ratings.containsKey(_index)) {
          _index = (_index + 1) % length;
        }
      }
      _showBack = false;
    });
  }

  void _reviewDifficult() {
    if (_difficult.isEmpty) return;
    setState(() {
      final difficult = Set<int>.of(_difficult);
      _ratings.removeWhere((index, _) => difficult.contains(index));
      _index = difficult.first;
      _sessionComplete = false;
      _showBack = false;
    });
  }

  Future<void> _speak(StudyFlashcard card) async {
    await _tts.stop();
    await _tts.speak(_showBack ? card.back : card.front);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cartões de estudo')),
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
                  options: const [5, 8, 12],
                  onChanged: (value) => setState(() => _count = value),
                  label: 'Cartões',
                ),
              ],
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => StudyAsyncView<FlashcardDeck>(
                  state: _controller.state,
                  onGenerate: _generate,
                  idleTitle: 'Transforme a cartilha em cartões',
                  idleDescription:
                      'Leia a pergunta, revele a resposta e marque o que precisa revisar.',
                  readyBuilder: _buildDeck,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeck(BuildContext context, FlashcardDeck deck) {
    if (deck.items.isEmpty) {
      return const Center(child: Text('Nenhum cartão foi gerado.'));
    }
    if (_sessionComplete) return _buildSessionResult(context, deck);
    final card = deck.items[_index.clamp(0, deck.items.length - 1)];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deck.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text('Cartão ${_index + 1} de ${deck.items.length}'),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: _ratings.length / deck.items.length,
                semanticsLabel: 'Progresso da sessão de cartões',
              ),
              const SizedBox(height: 12),
              FlashcardReviewStatus(
                source: widget.topic,
                remembered: _remembered.length,
                toReview: _difficult.length,
              ),
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: _showBack ? 'Resposta do cartão' : 'Pergunta do cartão',
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => setState(() => _showBack = !_showBack),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Card.filled(
                      key: ValueKey('$_index-$_showBack'),
                      color: _showBack
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: SizedBox(
                        width: double.infinity,
                        height: 300,
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _showBack ? 'Resposta' : 'Pergunta',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                _showBack ? card.back : card.front,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (_showBack && card.hint.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                Text(
                                  'Dica: ${card.hint}',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              if (_showBack) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Origem: ${widget.topic}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const Spacer(),
                              Text(
                                _showBack
                                    ? 'Como foi sua lembrança?'
                                    : 'Toque para revelar',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton.filledTonal(
                  tooltip: _showBack ? 'Ouvir resposta' : 'Ouvir pergunta',
                  onPressed: () => _speak(card),
                  icon: const Icon(Icons.volume_up_outlined),
                ),
              ),
              const SizedBox(height: 16),
              if (_showBack)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final rating in _RecallRating.values)
                      OutlinedButton(
                        onPressed: () => _rate(rating, deck.items.length),
                        child: Text(rating.label),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: const Text('Gerar novos cartões'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionResult(BuildContext context, FlashcardDeck deck) {
    final easy = _ratings.values
        .where((rating) => rating == _RecallRating.easy)
        .length;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.task_alt,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Sessão concluída',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${deck.items.length} cartões vistos • ${_difficult.length} para reforçar • $easy fáceis',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_difficult.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _reviewDifficult,
                    icon: const Icon(Icons.replay),
                    label: const Text('Revisar os mais difíceis'),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Gerar novos cartões'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RecallRating { forgot, difficult, good, easy }

extension on _RecallRating {
  String get label => switch (this) {
    _RecallRating.forgot => 'Não lembrei',
    _RecallRating.difficult => 'Difícil',
    _RecallRating.good => 'Bom',
    _RecallRating.easy => 'Fácil',
  };
}
