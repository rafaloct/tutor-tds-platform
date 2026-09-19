import 'package:flutter/material.dart';

/// Estado de espera compartilhado do Tutor TDS.
///
/// Usa conteúdo local e uma estrutura estática para não criar chamadas de IA
/// adicionais nem exibir uma porcentagem que o backend não consegue medir.
class TdsWaitExperience extends StatelessWidget {
  const TdsWaitExperience({
    super.key,
    required this.title,
    required this.status,
    required this.localTip,
    this.compact = false,
  });

  final String title;
  final String status;
  final String localTip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Semantics(
      liveRegion: true,
      label: '$title. $status',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SkeletonLine(widthFactor: 1, color: colors.surfaceContainerHighest),
          const SizedBox(height: 8),
          _SkeletonLine(
            widthFactor: 0.82,
            color: colors.surfaceContainerHighest,
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            _SkeletonLine(
              widthFactor: 0.58,
              color: colors.surfaceContainerHighest,
            ),
          ],
          const SizedBox(height: 16),
          Card.filled(
            margin: EdgeInsets.zero,
            color: colors.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: colors.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      localTip,
                      style: TextStyle(color: colors.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: content,
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: content,
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor, required this.color});

  final double widthFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: ExcludeSemantics(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}
