import 'package:flutter/material.dart';

class AssessmentFeedbackCard extends StatelessWidget {
  const AssessmentFeedbackCard({
    super.key,
    required this.isCorrect,
    required this.explanation,
    required this.source,
    required this.isLastQuestion,
  });

  final bool isCorrect;
  final String explanation;
  final String source;
  final bool isLastQuestion;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final nextAction = isLastQuestion
        ? 'Veja o resultado e escolha o que revisar.'
        : isCorrect
        ? 'Avance para a próxima questão.'
        : 'Releia a explicação e avance quando estiver pronto.';

    return Semantics(
      liveRegion: true,
      label: isCorrect ? 'Resposta correta' : 'Resposta para revisar',
      child: Card.filled(
        color: isCorrect ? colors.primaryContainer : colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_outline
                        : Icons.refresh_outlined,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCorrect ? 'Resposta correta!' : 'Vamos revisar',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(explanation),
              const Divider(height: 24),
              Text(
                'Fonte: $source',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Text('Próxima ação: $nextAction'),
            ],
          ),
        ),
      ),
    );
  }
}
