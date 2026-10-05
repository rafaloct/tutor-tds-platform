import 'package:flutter/material.dart';

import '../application/class_lifecycle_controller.dart';
import '../data/class_lifecycle_gateway.dart';
import '../models/class_lifecycle_models.dart';

class PrepareClassroomScreen extends StatefulWidget {
  const PrepareClassroomScreen({
    super.key,
    required this.gateway,
    this.onParticipantsTap,
  });

  final ClassLifecycleGateway gateway;
  final VoidCallback? onParticipantsTap;

  @override
  State<PrepareClassroomScreen> createState() => _PrepareClassroomScreenState();
}

class _PrepareClassroomScreenState extends State<PrepareClassroomScreen> {
  late final PrepareClassroomController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PrepareClassroomController(widget.gateway)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final current = _controller.startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      helpText: 'Data de início da turma',
    );
    if (picked == null) return;
    final end =
        _controller.endDate == null || _controller.endDate!.isBefore(picked)
        ? picked
        : _controller.endDate!;
    _controller.setDates(picked, end);
  }

  Future<void> _pickEndDate() async {
    final start = _controller.startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _controller.endDate ?? start,
      firstDate: start,
      lastDate: DateTime(2035),
      helpText: 'Data final da turma',
    );
    if (picked == null) return;
    _controller.setDates(start, picked);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Preparar turma')),
          body: _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.loading) {
      return Center(
        child: Semantics(
          label: 'Carregando permissões para preparar turma',
          child: const CircularProgressIndicator(),
        ),
      );
    }

    final bootstrap = _controller.bootstrap;
    if (bootstrap == null) {
      return _ErrorState(
        message:
            _controller.error ??
            'Não foi possível carregar a preparação da turma.',
        onRetry: _controller.load,
      );
    }

    if (!bootstrap.capabilities.canPrepare) {
      return _DeniedState(
        message:
            bootstrap.capabilities.prepareDeniedMessage ??
            'O servidor não liberou a preparação de turmas neste contexto.',
      );
    }

    final result = _controller.result;
    if (result != null) {
      return _SuccessState(result: result);
    }

    return SafeArea(
      child: Column(
        children: [
          _WizardProgress(step: _controller.currentStep),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (_controller.error != null)
                  _InlineError(message: _controller.error!),
                _stepContent(context),
              ],
            ),
          ),
          _NavigationBar(
            canBack: _controller.canGoBack,
            canAdvance: _controller.canAdvance,
            busy: _controller.busy,
            isReview: _controller.currentStep == 5,
            validationMessage: _controller.stepValidationMessage,
            onBack: _controller.back,
            onAdvance: _controller.currentStep == 5
                ? _controller.submit
                : () async => _controller.next(),
          ),
        ],
      ),
    );
  }

  Widget _stepContent(BuildContext context) {
    switch (_controller.currentStep) {
      case 0:
        return _WhereStep(controller: _controller);
      case 1:
        return _FormationStep(controller: _controller);
      case 2:
        return _DatesStep(
          controller: _controller,
          onPickStart: _pickStartDate,
          onPickEnd: _pickEndDate,
        );
      case 3:
        return _TeamStep(controller: _controller);
      case 4:
        return _ParticipantsStep(
          controller: _controller,
          onParticipantsTap: widget.onParticipantsTap,
        );
      case 5:
        return _ReviewStep(controller: _controller);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.step});
  final int step;

  static const labels = [
    'Onde será?',
    'Qual formação?',
    'Quando?',
    'Quem integra a equipe?',
    'Participantes',
    'Revisar',
  ];

  @override
  Widget build(BuildContext context) {
    final current = step + 1;
    return Semantics(
      label: 'Etapa $current de 6: ${labels[step]}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Etapa $current de 6',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: current / 6),
            const SizedBox(height: 10),
            Text(
              labels[step],
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhereStep extends StatelessWidget {
  const _WhereStep({required this.controller});
  final PrepareClassroomController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informe o território da oferta. O município de residência dos participantes não é usado aqui.',
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('class_name'),
          initialValue: controller.className,
          decoration: const InputDecoration(
            labelText: 'Nome da turma',
            hintText: 'Ex.: Turma Palmas Centro',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          textInputAction: TextInputAction.next,
          onChanged: controller.setClassName,
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: const Key('offer_municipality'),
          initialValue: controller.offerMunicipality,
          decoration: const InputDecoration(
            labelText: 'Município da oferta',
            hintText: 'Ex.: Palmas',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          textInputAction: TextInputAction.next,
          onChanged: controller.setOfferMunicipality,
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: const Key('offer_location'),
          initialValue: controller.offerLocation,
          decoration: const InputDecoration(
            labelText: 'Local físico da oferta',
            hintText: 'Ex.: laboratório, escola ou associação',
            prefixIcon: Icon(Icons.place_outlined),
          ),
          onChanged: controller.setOfferLocation,
        ),
      ],
    );
  }
}

class _FormationStep extends StatelessWidget {
  const _FormationStep({required this.controller});
  final PrepareClassroomController controller;

  @override
  Widget build(BuildContext context) {
    final bootstrap = controller.bootstrap!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Escolha a formação. A edição publicada é resolvida pelo servidor e não precisa de código técnico.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('program-${controller.programId}'),
          initialValue: controller.programId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Programa',
            prefixIcon: Icon(Icons.account_tree_outlined),
          ),
          items: bootstrap.programs
              .map(
                (item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: controller.busy ? null : controller.selectProgram,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey('course-${controller.courseId}'),
          initialValue: controller.courseId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Formação',
            prefixIcon: Icon(Icons.school_outlined),
          ),
          items: controller.courses
              .map(
                (item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: controller.busy || controller.programId == null
              ? null
              : controller.selectCourse,
        ),
        if (controller.busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (controller.publishedVersion != null) ...[
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.verified_outlined,
            title: 'Edição publicada',
            message: controller.publishedVersion!.label,
          ),
        ],
      ],
    );
  }
}

class _DatesStep extends StatelessWidget {
  const _DatesStep({
    required this.controller,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final PrepareClassroomController controller;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Defina o período da turma. O encerramento institucional continuará dependendo da readiness do servidor.',
        ),
        const SizedBox(height: 16),
        _DateTile(
          label: 'Data de início',
          value: controller.startDate,
          onTap: onPickStart,
        ),
        const SizedBox(height: 12),
        _DateTile(
          label: 'Data final',
          value: controller.endDate,
          onTap: onPickEnd,
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        alignment: Alignment.centerLeft,
      ),
      onPressed: onTap,
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value == null ? label : '$label: ${_formatDate(value!)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamStep extends StatelessWidget {
  const _TeamStep({required this.controller});
  final PrepareClassroomController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Escolha a equipe disponível para este programa. O servidor define quem pode ser atribuído.',
        ),
        const SizedBox(height: 16),
        if (controller.staffError != null) ...[
          _InlineError(message: controller.staffError!),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          key: ValueKey('teacher-${controller.teacherId}'),
          initialValue: controller.teacherId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Professor responsável',
            prefixIcon: Icon(Icons.person_outlined),
          ),
          items: controller.teachers
              .map(
                (member) => DropdownMenuItem(
                  value: member.id,
                  child: Text(member.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: controller.setTeacher,
        ),
        const SizedBox(height: 20),
        Text('Monitores', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (controller.monitors.isEmpty)
          const Text('Nenhum monitor disponível para esta oferta.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.monitors
                .map(
                  (member) => FilterChip(
                    label: Text(member.name),
                    selected: controller.monitorIds.contains(member.id),
                    onSelected: (selected) =>
                        controller.toggleMonitor(member.id, selected),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _ParticipantsStep extends StatelessWidget {
  const _ParticipantsStep({
    required this.controller,
    required this.onParticipantsTap,
  });

  final PrepareClassroomController controller;
  final VoidCallback? onParticipantsTap;

  @override
  Widget build(BuildContext context) {
    final capacity = controller.capacity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Participantes continuam no fluxo já existente. Aqui você confere como o servidor aplicará capacidade e eventual exceção.',
        ),
        const SizedBox(height: 16),
        if (capacity != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    capacity.deferredToParticipants
                        ? 'Capacidade validada ao incluir participantes'
                        : "${capacity.occupancy} de ${capacity.capacity} vagas ocupadas",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(capacity.message),
                  if (capacity.requiresOverrideReason) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'A exceção só será enviada com justificativa explícita na revisão.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onParticipantsTap,
          icon: const Icon(Icons.manage_accounts_outlined),
          label: const Text('Abrir participantes'),
        ),
        if (onParticipantsTap == null) ...[
          const SizedBox(height: 8),
          Text(
            'O fluxo de participantes não está disponível neste contexto.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.controller});
  final PrepareClassroomController controller;

  @override
  Widget build(BuildContext context) {
    final capacity = controller.capacity!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confira antes de preparar. Nenhum identificador técnico precisa ser informado.',
        ),
        const SizedBox(height: 16),
        _ReviewRow(label: 'Turma', value: controller.className.trim()),
        _ReviewRow(
          label: 'Onde',
          value:
              "${controller.offerMunicipality.trim()} • ${controller.offerLocation.trim()}",
        ),
        _ReviewRow(
          label: 'Formação',
          value:
              "${controller.selectedProgram?.name ?? ''} • ${controller.selectedCourse?.name ?? ''}",
        ),
        _ReviewRow(
          label: 'Edição',
          value:
              controller.publishedVersion?.label ?? 'Confirmada pelo servidor',
        ),
        _ReviewRow(
          label: 'Período',
          value:
              "${_formatDate(controller.startDate!)} a ${_formatDate(controller.endDate!)}",
        ),
        _ReviewRow(
          label: 'Professor',
          value: controller.selectedTeacher?.name ?? '',
        ),
        _ReviewRow(
          label: 'Monitores',
          value: controller.selectedMonitors.isEmpty
              ? 'Nenhum'
              : controller.selectedMonitors.map((item) => item.name).join(', '),
        ),
        _ReviewRow(
          label: 'Capacidade',
          value: capacity.deferredToParticipants
              ? 'Validada pelo servidor ao adicionar participantes'
              : '${capacity.occupancy} de ${capacity.capacity}',
        ),
        if (capacity.requiresOverrideReason) ...[
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('capacity_override_reason'),
            initialValue: controller.capacityOverrideReason,
            decoration: const InputDecoration(
              labelText: 'Justificativa da exceção de capacidade',
              helperText:
                  'Obrigatória porque o servidor sinalizou uma exceção auditável.',
              prefixIcon: Icon(Icons.rule_outlined),
            ),
            maxLines: 3,
            onChanged: controller.setCapacityOverrideReason,
          ),
        ],
        const SizedBox(height: 16),
        const _InfoCard(
          icon: Icons.shield_outlined,
          title: 'Autorização',
          message:
              'O botão apenas envia a solicitação. O servidor continua sendo a autoridade final.',
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.canBack,
    required this.canAdvance,
    required this.busy,
    required this.isReview,
    required this.validationMessage,
    required this.onBack,
    required this.onAdvance,
  });

  final bool canBack;
  final bool canAdvance;
  final bool busy;
  final bool isReview;
  final String? validationMessage;
  final VoidCallback onBack;
  final Future<void> Function() onAdvance;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (validationMessage != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    validationMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (canBack)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : onBack,
                        child: const Text('Voltar'),
                      ),
                    ),
                  if (canBack) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: canAdvance ? onAdvance : null,
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isReview ? 'Preparar turma' : 'Continuar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(message),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Não foi possível concluir esta etapa'),
        subtitle: Text(message),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeniedState extends StatelessWidget {
  const _DeniedState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 42),
                const SizedBox(height: 12),
                Text(
                  'Preparação indisponível',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.result});
  final PreparedClassroomResult result;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Turma preparada',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(result.name, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  'Situação: ${result.statusLabel}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Participantes continuam sendo gerenciados pelo fluxo já existente.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
