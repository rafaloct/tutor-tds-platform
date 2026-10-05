import 'package:flutter/material.dart';

import '../models/cartilha.dart';

/// A deliberately local interaction: it does not emit an assessment, presence,
/// frequency, completion, or certificate event.
class LearningExperienceCard extends StatefulWidget {
  final ExperienceBlock experience;
  final VoidCallback? onAskTutor;

  const LearningExperienceCard({
    super.key,
    required this.experience,
    this.onAskTutor,
  });

  @override
  State<LearningExperienceCard> createState() => _LearningExperienceCardState();
}

class _LearningExperienceCardState extends State<LearningExperienceCard> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final style = _style(widget.experience.kind, Theme.of(context).colorScheme);
    return Semantics(
      container: true,
      label: '${style.title}. ${widget.experience.objective}',
      child: Card(
        margin: const EdgeInsets.only(top: 12),
        color: style.background,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(style.icon, color: style.foreground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      style.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.experience.objective,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _done
                        ? null
                        : () => setState(() => _done = true),
                    icon: Icon(_done ? Icons.check_circle : Icons.task_alt),
                    label: Text(
                      _done
                          ? 'Marcada nesta sessão'
                          : (widget.experience.actionLabel ?? style.action),
                    ),
                  ),
                  if (widget.onAskTutor != null)
                    TextButton.icon(
                      onPressed: widget.onAskTutor,
                      icon: const Icon(Icons.psychology_outlined),
                      label: const Text('Conversar com o Tutor IA'),
                    ),
                ],
              ),
              if (_done) ...[
                const SizedBox(height: 8),
                const Text(
                  'Esta atividade é de prática e não conta como avaliação, presença, frequência ou certificado.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

_ExperienceStyle _style(ExperienceKind kind, ColorScheme colors) =>
    switch (kind) {
      ExperienceKind.scenario => _ExperienceStyle(
        'Situação para explorar',
        'Escolher um caminho',
        Icons.alt_route,
        colors.primary,
        colors.primaryContainer,
      ),
      ExperienceKind.reveal => _ExperienceStyle(
        'Descubra a ideia-chave',
        'Revelar reflexão',
        Icons.visibility_outlined,
        colors.tertiary,
        colors.tertiaryContainer,
      ),
      ExperienceKind.reflection => _ExperienceStyle(
        'Reflexão',
        'Refletir sobre minha realidade',
        Icons.self_improvement_outlined,
        colors.secondary,
        colors.secondaryContainer,
      ),
      ExperienceKind.actionChallenge => _ExperienceStyle(
        'Desafio de ação',
        'Marcar pequeno passo',
        Icons.task_alt,
        colors.primary,
        colors.surfaceContainerHighest,
      ),
    };

class _ExperienceStyle {
  const _ExperienceStyle(
    this.title,
    this.action,
    this.icon,
    this.foreground,
    this.background,
  );
  final String title;
  final String action;
  final IconData icon;
  final Color foreground;
  final Color background;
}
