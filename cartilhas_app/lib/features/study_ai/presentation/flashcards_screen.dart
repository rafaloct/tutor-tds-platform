import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/study_ai_service.dart';
import '../models/study_models.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generate() {
    setState(() {
      _index = 0;
      _showBack = false;
      _difficult.clear();
    });
    _controller.generate(
      () => context.read<StudyAiService>().generateFlashcards(
        topic: widget.topic,
        difficulty: _difficulty,
        count: _count,
      ),
    );
  }

  Iterable<int> _reviewOrder(int length) sync* {
    for (final index in _difficult) {
      if (index < length) yield index;
    }
    for (var index = 0; index < length; index++) {
      if (!_difficult.contains(index)) yield index;
    }
  }

  void _rate(bool difficult, int length) {
    if (difficult) {
      _difficult.add(_index);
    } else {
      _difficult.remove(_index);
    }
    final order = _reviewOrder(length).toList(growable: false);
    final currentPosition = order.indexOf(_index);
    setState(() {
      _index = order[(currentPosition + 1) % order.length];
      _showBack = false;
    });
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
                  Text('${_index + 1}/${deck.items.length}'),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: (_index + 1) / deck.items.length),
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
              const SizedBox(height: 16),
              if (_showBack)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _rate(true, deck.items.length),
                      icon: const Icon(Icons.replay),
                      label: const Text('Revisar novamente'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _rate(false, deck.items.length),
                      icon: const Icon(Icons.check),
                      label: const Text('Eu lembrei'),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: const Text('Gerar novos cartões'),
              ),
              if (_difficult.isNotEmpty)
                Text(
                  '${_difficult.length} cartão(ões) marcado(s) para revisão',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
