import 'package:flutter/material.dart';

import 'linkify_text.dart';

enum TutorResponseFeedback { useful, notUseful, report }

/// Exibe uma resposta do Tutor em camadas sem inventar citações que o
/// contrato atual do gateway não entrega.
class TutorResponseCard extends StatefulWidget {
  const TutorResponseCard({
    super.key,
    required this.text,
    required this.onListen,
    required this.onCreateCards,
    required this.onPracticeQuiz,
    required this.onContinue,
    required this.onFollowUp,
    required this.onFeedback,
    this.contextLabel,
    this.child,
  });

  final String text;
  final String? contextLabel;
  final VoidCallback onListen;
  final VoidCallback onCreateCards;
  final VoidCallback onPracticeQuiz;
  final VoidCallback onContinue;
  final ValueChanged<String> onFollowUp;
  final ValueChanged<TutorResponseFeedback> onFeedback;
  final Widget? child;

  @override
  State<TutorResponseCard> createState() => _TutorResponseCardState();
}

class _TutorResponseCardState extends State<TutorResponseCard> {
  TutorResponseFeedback? _feedback;

  List<String> get _paragraphs => widget.text
      .split(RegExp(r'\n\s*\n'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  void _selectFeedback(TutorResponseFeedback value) {
    if (_feedback != null) return;
    setState(() => _feedback = value);
    widget.onFeedback(value);
  }

  @override
  Widget build(BuildContext context) {
    final paragraphs = _paragraphs;
    final directAnswer = paragraphs.isEmpty ? widget.text : paragraphs.first;
    final details = paragraphs.skip(1).join('\n\n');
    final label = widget.contextLabel?.trim();
    final hasContext = label != null && label.isNotEmpty;

    return Semantics(
      container: true,
      label: 'Resposta do Tutor TDS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Resposta direta',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          LinkifyText(directAnswer),
          if (details.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Entenda melhor'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: LinkifyText(details),
                ),
              ],
            ),
          if (widget.child != null) ...[
            const SizedBox(height: 8),
            widget.child!,
          ],
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.source_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasContext
                      ? 'Contexto enviado ao Tutor: $label. Confira informações importantes na cartilha.'
                      : 'O serviço atual não informou uma fonte específica. Confira informações importantes na cartilha.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.volume_up_outlined, size: 18),
                label: const Text('Ouvir'),
                onPressed: widget.onListen,
              ),
              ActionChip(
                avatar: const Icon(Icons.style_outlined, size: 18),
                label: const Text('Criar cartões'),
                onPressed: widget.onCreateCards,
              ),
              ActionChip(
                avatar: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text('Praticar quiz'),
                onPressed: widget.onPracticeQuiz,
              ),
              ActionChip(
                avatar: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Continuar pergunta'),
                onPressed: widget.onContinue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Você pode perguntar também',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Mostre um exemplo'),
                onPressed: () => widget.onFollowUp(
                  'Mostre um exemplo prático da explicação anterior.',
                ),
              ),
              ActionChip(
                label: const Text('Resuma em 3 pontos'),
                onPressed: () => widget.onFollowUp(
                  'Resuma a explicação anterior em três pontos curtos.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_feedback == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Esta resposta ajudou?'),
                IconButton(
                  tooltip: 'Útil',
                  onPressed: () =>
                      _selectFeedback(TutorResponseFeedback.useful),
                  icon: const Icon(Icons.thumb_up_outlined, size: 18),
                ),
                IconButton(
                  tooltip: 'Não ajudou',
                  onPressed: () =>
                      _selectFeedback(TutorResponseFeedback.notUseful),
                  icon: const Icon(Icons.thumb_down_outlined, size: 18),
                ),
                IconButton(
                  tooltip: 'Reportar problema',
                  onPressed: () =>
                      _selectFeedback(TutorResponseFeedback.report),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Feedback registrado',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}
