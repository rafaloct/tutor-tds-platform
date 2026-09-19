import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/study_ai_service.dart';
import '../models/study_models.dart';
import 'study_async_view.dart';
import 'study_generation_controls.dart';
import 'study_material_controller.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.topic});

  final String topic;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final StudyMaterialController<StudySummary> _controller =
      StudyMaterialController();
  SummaryLength _length = SummaryLength.quick;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generate() {
    _controller.generate(
      () => context.read<StudyAiService>().generateSummary(
        topic: widget.topic,
        length: _length,
      ),
    );
  }

  String _plainText(StudySummary summary) => [
    summary.title,
    '',
    summary.overview,
    '',
    'Pontos-chave:',
    ...summary.keyPoints.map((item) => '• $item'),
    '',
    'Exemplos práticos:',
    ...summary.practicalExamples.map((item) => '• $item'),
    '',
    'Perguntas para revisar:',
    ...summary.reviewQuestions.map((item) => '• $item'),
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resumo com IA')),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            StudyConfigurationPanel(
              source: widget.topic,
              controls: [
                SegmentedButton<SummaryLength>(
                  segments: SummaryLength.values
                      .map(
                        (value) => ButtonSegment(
                          value: value,
                          label: Text(value.label),
                        ),
                      )
                      .toList(),
                  selected: {_length},
                  onSelectionChanged: (selection) =>
                      setState(() => _length = selection.first),
                ),
              ],
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => StudyAsyncView<StudySummary>(
                  state: _controller.state,
                  onGenerate: _generate,
                  idleTitle: 'Resuma a cartilha',
                  idleDescription:
                      'Escolha o tamanho para receber conceitos, exemplos e perguntas de revisão.',
                  readyBuilder: _buildSummary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, StudySummary summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Copiar resumo',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _plainText(summary)),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Resumo copiado.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(summary.overview),
              _SummarySection(
                title: 'Pontos-chave',
                icon: Icons.key_outlined,
                items: summary.keyPoints,
              ),
              _SummarySection(
                title: 'Exemplos práticos',
                icon: Icons.lightbulb_outline,
                items: summary.practicalExamples,
              ),
              _SummarySection(
                title: 'Perguntas para revisar',
                icon: Icons.help_outline,
                items: summary.reviewQuestions,
              ),
              Center(
                child: TextButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Gerar outro resumo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
