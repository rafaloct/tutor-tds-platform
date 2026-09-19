import 'package:flutter/material.dart';

import '../../../widgets/tds_wait_experience.dart';
import 'study_material_controller.dart';

class StudyAsyncView<T> extends StatelessWidget {
  const StudyAsyncView({
    super.key,
    required this.state,
    required this.onGenerate,
    required this.readyBuilder,
    required this.idleTitle,
    required this.idleDescription,
    this.idleBuilder,
    this.generateLabel = 'Gerar com IA',
    this.loadingTitle = 'Preparando seu material',
    this.loadingDescription = 'Organizando o conteúdo selecionado...',
    this.localTip =
        'Enquanto isso, tente lembrar os conceitos principais desta cartilha.',
  });

  final StudyLoadState<T> state;
  final VoidCallback onGenerate;
  final Widget Function(BuildContext context, T data) readyBuilder;
  final WidgetBuilder? idleBuilder;
  final String idleTitle;
  final String idleDescription;
  final String generateLabel;
  final String loadingTitle;
  final String loadingDescription;
  final String localTip;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      StudyLoadStatus.loading => TdsWaitExperience(
        title: loadingTitle,
        status: loadingDescription,
        localTip: localTip,
      ),
      StudyLoadStatus.ready => readyBuilder(context, state.data as T),
      StudyLoadStatus.failure => _EmptyStudyState(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível gerar',
        description: state.error ?? 'Tente novamente em instantes.',
        actionLabel: 'Tentar novamente',
        onAction: onGenerate,
      ),
      _ =>
        idleBuilder != null
            ? idleBuilder!(context)
            : _EmptyStudyState(
                icon: Icons.auto_awesome_outlined,
                title: idleTitle,
                description: idleDescription,
                actionLabel: generateLabel,
                onAction: onGenerate,
              ),
    };
  }
}

class _EmptyStudyState extends StatelessWidget {
  const _EmptyStudyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(description, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.auto_awesome),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
