import 'package:flutter/material.dart';

import '../../classrooms/application/team_capability.dart';
import '../../class_lifecycle/models/class_lifecycle_models.dart';

class ManagementWorkspaceScreen extends StatelessWidget {
  const ManagementWorkspaceScreen({
    super.key,
    required this.operationScopeCount,
    required this.editorProgramCount,
    required this.teamCapability,
    this.lifecycleCapabilities,
    this.onParticipantsTap,
    this.onPrepareClassTap,
    this.onCloseClassTap,
    this.onContentTap,
    this.onTeamTap,
    this.onAttendanceTap,
  });

  final int operationScopeCount;
  final int editorProgramCount;
  final TeamCapabilitySnapshot? teamCapability;
  final ClassLifecycleCapabilities? lifecycleCapabilities;
  final VoidCallback? onParticipantsTap;
  final VoidCallback? onPrepareClassTap;
  final VoidCallback? onCloseClassTap;
  final VoidCallback? onContentTap;
  final VoidCallback? onTeamTap;
  final VoidCallback? onAttendanceTap;

  bool get _hasTeamAccess => teamCapability?.hasAccess ?? false;
  bool get _hasLifecycleAccess =>
      lifecycleCapabilities?.hasManagementSurface ?? false;

  @override
  Widget build(BuildContext context) {
    final team = teamCapability;
    final hasActions =
        operationScopeCount > 0 ||
        editorProgramCount > 0 ||
        _hasTeamAccess ||
        _hasLifecycleAccess;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestão')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Gestão do programa',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'As ferramentas abaixo aparecem somente quando o servidor confirma '
            'seu acesso ao contexto correspondente.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (operationScopeCount > 0)
                _CapabilityChip(
                  icon: Icons.manage_accounts_outlined,
                  label: _countLabel(
                    operationScopeCount,
                    'contexto de participantes',
                    'contextos de participantes',
                  ),
                ),
              if (_hasLifecycleAccess)
                const _CapabilityChip(
                  icon: Icons.event_note_outlined,
                  label: 'gestão de ciclo da turma',
                ),
              if (_hasTeamAccess)
                _CapabilityChip(
                  icon: Icons.groups_outlined,
                  label: _countLabel(
                    team!.classrooms.length,
                    'turma da equipe',
                    'turmas da equipe',
                  ),
                ),
              if (editorProgramCount > 0)
                _CapabilityChip(
                  icon: Icons.edit_note_outlined,
                  label: _countLabel(
                    editorProgramCount,
                    'programa de conteúdo',
                    'programas de conteúdo',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (!hasActions)
            const _EmptyManagementState()
          else ...[
            if (lifecycleCapabilities?.canPrepare ?? false)
              _ManagementActionCard(
                icon: Icons.add_business_outlined,
                title: 'Preparar turma',
                subtitle:
                    'Definir local, formação, período e equipe em um fluxo guiado.',
                onTap: onPrepareClassTap,
              ),
            if (lifecycleCapabilities?.canClose ?? false)
              _ManagementActionCard(
                icon: Icons.lock_clock_outlined,
                title: 'Encerrar turma',
                subtitle:
                    'Conferir pendências e readiness antes do encerramento institucional.',
                onTap: onCloseClassTap,
              ),
            if (operationScopeCount > 0)
              _ManagementActionCard(
                icon: Icons.manage_accounts_outlined,
                title: 'Participantes',
                subtitle:
                    'Localizar ou cadastrar pessoa, confirmar matrícula e vínculo com a turma.',
                onTap: onParticipantsTap,
              ),
            if (_hasTeamAccess)
              _ManagementActionCard(
                icon: Icons.groups_outlined,
                title: team!.hasTeacherCockpit
                    ? 'Turmas e equipe'
                    : 'Acompanhamento da turma',
                subtitle: team.hasTeacherCockpit
                    ? 'Acompanhar turma, participantes e ações da equipe.'
                    : 'Acompanhar somente as turmas em que seu acesso foi confirmado.',
                onTap: onTeamTap,
              ),
            if (_hasTeamAccess)
              _ManagementActionCard(
                icon: Icons.qr_code_scanner_outlined,
                title: 'Registrar presença',
                subtitle:
                    'Abrir o fluxo de presença e evidências no contexto autorizado.',
                onTap: onAttendanceTap,
              ),
            if (editorProgramCount > 0)
              _ManagementActionCard(
                icon: Icons.edit_note_outlined,
                title: 'Conteúdos',
                subtitle:
                    'Criar e revisar conteúdos apenas nos programas liberados para sua conta.',
                onTap: onContentTap,
              ),
          ],
        ],
      ),
    );
  }

  static String _countLabel(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 18), label: Text(label));
}

class _ManagementActionCard extends StatelessWidget {
  const _ManagementActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 16),
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
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

class _EmptyManagementState extends StatelessWidget {
  const _EmptyManagementState();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 36),
          const SizedBox(height: 12),
          Text(
            'Nenhuma ferramenta de gestão disponível',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Seu acesso pode ter mudado. Volte à tela inicial para atualizar as permissões.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
