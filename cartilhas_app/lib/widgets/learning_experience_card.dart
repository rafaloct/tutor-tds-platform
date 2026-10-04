import 'package:flutter/material.dart';

import '../models/cartilha.dart';

const _experienceTypes = <String>{
  'scenario',
  'reveal',
  'reflection',
  'action_challenge',
};

bool isLearningExperienceType(String type) => _experienceTypes.contains(type);

class LearningExperienceCard extends StatelessWidget {
  const LearningExperienceCard({
    super.key,
    required this.message,
    this.onSpeak,
  });

  final Message message;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final config = _configFor(message.type, Theme.of(context).colorScheme);
    return Semantics(
      container: true,
      label: config.title + '. ' + message.content,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(color: config.background),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: config.foreground.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Icon(
                          config.icon,
                          color: config.foreground,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            config.helper,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message.content,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                if (onSpeak != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Ouvir',
                      visualDensity: VisualDensity.compact,
                      onPressed: onSpeak,
                      icon: const Icon(Icons.volume_up_outlined, size: 19),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LearningExperienceChoices extends StatelessWidget {
  const LearningExperienceChoices({
    super.key,
    required this.message,
    required this.enabled,
    required this.onSelected,
  });

  final Message message;
  final bool enabled;
  final ValueChanged<Option> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = message.options ?? const <Option>[];
    if (options.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final config = _configFor(message.type, colors);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _choicePrompt(message.type),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...options.indexed.map((entry) {
              final index = entry.$1;
              final option = entry.$2;
              final icon = _choiceIcon(message.type, index);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  button: true,
                  label: option.label,
                  child: OutlinedButton.icon(
                    onPressed: enabled ? () => onSelected(option) : null,
                    icon: Icon(icon, color: config.foreground),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(option.label),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      alignment: Alignment.centerLeft,
                      foregroundColor: colors.onSurface,
                      side: BorderSide(color: colors.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

_ExperienceConfig _configFor(String type, ColorScheme colors) {
  return switch (type) {
    'scenario' => _ExperienceConfig(
      title: 'Situação real',
      helper: 'Escolha um caminho e observe o que ele provoca.',
      icon: Icons.alt_route,
      foreground: colors.primary,
      background: colors.primaryContainer.withValues(alpha: 0.34),
    ),
    'reveal' => _ExperienceConfig(
      title: 'Descubra',
      helper: 'Revele a ideia-chave quando estiver pronto.',
      icon: Icons.visibility_outlined,
      foreground: colors.tertiary,
      background: colors.tertiaryContainer.withValues(alpha: 0.32),
    ),
    'reflection' => _ExperienceConfig(
      title: 'E na sua realidade?',
      helper: 'Aqui não existe resposta certa; use sua experiência.',
      icon: Icons.self_improvement_outlined,
      foreground: colors.secondary,
      background: colors.secondaryContainer.withValues(alpha: 0.36),
    ),
    'action_challenge' => _ExperienceConfig(
      title: 'Coloque em prática',
      helper: 'Uma ação curta para levar o conteúdo para o dia a dia.',
      icon: Icons.task_alt,
      foreground: colors.primary,
      background: colors.surfaceContainerHighest,
    ),
    _ => _ExperienceConfig(
      title: 'Atividade',
      helper: 'Explore o conteúdo no seu ritmo.',
      icon: Icons.explore_outlined,
      foreground: colors.primary,
      background: colors.surfaceContainerHighest,
    ),
  };
}

String _choicePrompt(String type) => switch (type) {
  'scenario' => 'O que você faria?',
  'reveal' => 'Quando quiser, revele:',
  'reflection' => 'Qual opção mais combina com você?',
  'action_challenge' => 'Como quer seguir?',
  _ => 'Escolha uma opção:',
};

IconData _choiceIcon(String type, int index) => switch (type) {
  'scenario' => index == 0 ? Icons.looks_one_outlined : Icons.looks_two_outlined,
  'reveal' => Icons.visibility_outlined,
  'reflection' => Icons.chat_bubble_outline,
  'action_challenge' => Icons.check_circle_outline,
  _ => Icons.arrow_forward,
};

class _ExperienceConfig {
  const _ExperienceConfig({
    required this.title,
    required this.helper,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String title;
  final String helper;
  final IconData icon;
  final Color foreground;
  final Color background;
}
