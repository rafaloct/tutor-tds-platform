import 'package:flutter/material.dart';

class StudyResumeCard extends StatelessWidget {
  const StudyResumeCard({
    super.key,
    required this.courseTitle,
    required this.progress,
    required this.isCompleted,
    required this.onPressed,
  });

  final String courseTitle;
  final double progress;
  final bool isCompleted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.filled(
      margin: const EdgeInsets.only(top: 16),
      color: colors.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                isCompleted ? Icons.replay_outlined : Icons.play_arrow_rounded,
                color: colors.onPrimaryContainer,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompleted ? 'Rever cartilha' : 'Continuar estudando',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      courseTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isCompleted) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        backgroundColor: colors.surface.withValues(alpha: 0.5),
                        color: colors.primary,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
