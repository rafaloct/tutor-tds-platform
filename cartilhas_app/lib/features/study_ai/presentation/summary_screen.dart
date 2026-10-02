import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../analytics/telemetry_route.dart';

import '../data/study_ai_service.dart';
import '../data/study_summary_repository.dart';
import '../models/study_models.dart';
import 'study_async_view.dart';
import 'study_generation_controls.dart';
import 'study_material_controller.dart';
import 'assessment_screen.dart';
import 'flashcards_screen.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({
    super.key,
    required this.topic,
    this.courseId,
    this.repository = const StudySummaryRepository(),
  });

  final String topic;
  final String? courseId;
  final StudySummaryRepository repository;

  String get resolvedCourseId => courseId ?? topic;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final StudyMaterialController<StudySummary> _controller =
      StudyMaterialController();
  SummaryLength _length = SummaryLength.quick;
  SavedStudySummary? _savedSummary;
  bool _isViewingSaved = false;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('pt-BR');
    _tts.setSpeechRate(0.5);
    _checkSavedSummary();
  }

  Future<void> _checkSavedSummary() async {
    final saved = await widget.repository.load(widget.resolvedCourseId);
    if (mounted) {
      setState(() => _savedSummary = saved);
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  void _openSaved(SavedStudySummary saved) {
    setState(() {
      _length = saved.length;
      _isViewingSaved = true;
    });
    _controller.setData(saved.summary);
  }

  void _generate() {
    setState(() => _isViewingSaved = false);
    _controller.generate(() async {
      final summary = await context.read<StudyAiService>().generateSummary(
        topic: widget.topic,
        length: _length,
      );
      final saved = SavedStudySummary(
        courseId: widget.resolvedCourseId,
        topic: widget.topic,
        length: _length,
        summary: summary,
        createdAt: DateTime.now(),
      );
      await widget.repository.save(saved);
      if (mounted) {
        setState(() => _savedSummary = saved);
      }
      return summary;
    });
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y às $h:$min';
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

  Future<void> _listen(StudySummary summary) async {
    await _tts.stop();
    await _tts.speak(_plainText(summary));
  }

  void _openCards() {
    Navigator.push(
      context,
      trackedRoute(
        pageId: 'flashcards',
        courseId: widget.resolvedCourseId,
        featureId: 'flashcards',
        builder: (_) => FlashcardsScreen(topic: widget.topic),
      ),
    );
  }

  void _openQuiz() {
    Navigator.push(
      context,
      trackedRoute(
        pageId: 'assessment',
        courseId: widget.resolvedCourseId,
        featureId: 'quiz',
        builder: (_) => AssessmentScreen(
          topic: widget.topic,
          courseId: widget.resolvedCourseId,
          mode: AssessmentMode.quiz,
        ),
      ),
    );
  }

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
                  idleBuilder: _buildIdle,
                  readyBuilder: _buildSummary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    if (_savedSummary != null) {
      final saved = _savedSummary!;
      final formattedDate = _formatDate(saved.createdAt);
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
                              Icons.history_edu_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Último resumo salvo',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Chip(
                              label: Text(saved.length.label),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Salvo em $formattedDate. Você pode reabrir este conteúdo offline ou gerar um novo resumo com a IA.',
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
                    onPressed: () => _openSaved(saved),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Abrir último resumo'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Gerar novo resumo'),
                  ),
                ),
              ],
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
                'Resuma a cartilha',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha o tamanho para receber conceitos, exemplos e perguntas de revisão.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Gerar com IA'),
              ),
            ],
          ),
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
              if (_isViewingSaved && _savedSummary != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.offline_pin_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Resumo offline • Salvo em ${_formatDate(_savedSummary!.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
              Card.outlined(
                child: ExpansionTile(
                  initiallyExpanded: true,
                  leading: const Icon(Icons.subject_outlined),
                  title: const Text('Visão geral'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(summary.overview),
                    ),
                  ],
                ),
              ),
              _SummarySection(
                title: 'Pontos-chave',
                icon: Icons.key_outlined,
                items: summary.keyPoints,
              ),
              const SizedBox(height: 16),
              Text(
                'Origem: ${widget.topic}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.volume_up_outlined, size: 18),
                    label: const Text('Ouvir'),
                    onPressed: () => _listen(summary),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Compartilhar'),
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        title: summary.title,
                        subject: 'Resumo Tutor TDS',
                        text: _plainText(summary),
                      ),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.style_outlined, size: 18),
                    label: const Text('Criar cartões'),
                    onPressed: _openCards,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.quiz_outlined, size: 18),
                    label: const Text('Praticar quiz'),
                    onPressed: _openQuiz,
                  ),
                ],
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
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: Icon(icon),
          title: Text(title),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
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
    );
  }
}
