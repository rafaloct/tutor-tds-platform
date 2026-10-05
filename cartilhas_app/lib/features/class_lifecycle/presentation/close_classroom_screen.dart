import 'package:flutter/material.dart';

import '../application/class_lifecycle_controller.dart';
import '../data/class_lifecycle_gateway.dart';

class CloseClassroomScreen extends StatefulWidget {
  const CloseClassroomScreen({super.key, required this.gateway});

  final ClassLifecycleGateway gateway;

  @override
  State<CloseClassroomScreen> createState() => _CloseClassroomScreenState();
}

class _CloseClassroomScreenState extends State<CloseClassroomScreen> {
  late final CloseClassroomController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CloseClassroomController(widget.gateway)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Encerrar turma')),
          body: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final bootstrap = _controller.bootstrap;
    if (bootstrap == null) {
      return _StateCard(
        icon: Icons.cloud_off_outlined,
        title: 'Readiness indisponível',
        message:
            _controller.error ??
            'Não foi possível consultar o estado da turma.',
        action: FilledButton(
          onPressed: _controller.load,
          child: const Text('Tentar novamente'),
        ),
      );
    }

    if (_controller.result != null) {
      return _StateCard(
        icon: Icons.check_circle_outlined,
        title: 'Turma encerrada',
        message:
            'Situação: ${_controller.result!.statusLabel}. O encerramento não emitiu nem fabricou certificados.',
      );
    }

    final readiness = _controller.readiness;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text(
          'Antes de encerrar',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Confira as pendências operacionais. O servidor decide se a turma está pronta para encerramento.',
        ),
        const SizedBox(height: 18),
        if (bootstrap.manageableClasses.isEmpty)
          const _StateCard(
            icon: Icons.groups_outlined,
            title: 'Nenhuma turma disponível',
            message:
                'O servidor não retornou turmas gerenciáveis neste contexto.',
          )
        else ...[
          DropdownButtonFormField<String>(
            key: ValueKey('close-class-${_controller.selectedClassId}'),
            initialValue: _controller.selectedClassId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Turma',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
            items: bootstrap.manageableClasses
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      '${item.name} • ${item.statusLabel}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: _controller.busy ? null : _controller.selectClass,
          ),
          if (_controller.busy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          if (_controller.error != null) ...[
            const SizedBox(height: 14),
            _WarningCard(
              title: 'Não foi possível atualizar a readiness',
              message: _controller.error!,
            ),
          ],
          if (readiness != null) ...[
            const SizedBox(height: 18),
            _ReadinessCard(
              icon: Icons.event_available_outlined,
              label: 'Encontros em aberto',
              value: '${readiness.openSessions}',
              ok: readiness.openSessions == 0,
            ),
            _ReadinessCard(
              icon: Icons.fact_check_outlined,
              label: 'Reposições pendentes',
              value: '${readiness.pendingAttendance}',
              ok: readiness.pendingAttendance == 0,
            ),
            _ReadinessCard(
              icon: Icons.inventory_2_outlined,
              label: 'Evidências pendentes',
              value: '${readiness.pendingEvidence}',
              ok: readiness.pendingEvidence == 0,
            ),
            _ReadinessCard(
              icon: Icons.people_outline,
              label: 'Participantes',
              value: '${readiness.participants}',
              ok: true,
            ),
            _ReadinessCard(
              icon: Icons.workspace_premium_outlined,
              label: 'Pedidos de certificado',
              value: '${readiness.pendingCertificateRequests}',
              ok: true,
            ),
            const SizedBox(height: 12),
            const _WarningCard(
              title: 'Certificados são independentes',
              message:
                  'Encerrar a turma não emite, não valida e não fabrica certificados. O fluxo de certificação continua separado.',
            ),
            if (readiness.blockers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pendências para resolver',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      for (final blocker in readiness.blockers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(Icons.circle, size: 8),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(blocker)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (!bootstrap.capabilities.canClose)
              _WarningCard(
                title: 'Encerramento não autorizado',
                message:
                    bootstrap.capabilities.closeDeniedMessage ??
                    'Você pode acompanhar a readiness, mas o servidor não liberou o encerramento.',
              )
            else ...[
              TextFormField(
                key: const Key('close_reason'),
                initialValue: _controller.closeReason,
                enabled: readiness.canClose && !_controller.busy,
                decoration: const InputDecoration(
                  labelText: 'Motivo do encerramento',
                  hintText: 'Ex.: atividades concluídas e evidências revisadas',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 3,
                onChanged: _controller.setCloseReason,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _controller.certificateNoticeConfirmed,
                onChanged: readiness.canClose && !_controller.busy
                    ? (value) => _controller.setCertificateNoticeConfirmed(
                        value ?? false,
                      )
                    : null,
                title: const Text(
                  'Entendo que encerrar a turma não emite certificados.',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _controller.canSubmit
                    ? () => _confirmAndClose(context)
                    : null,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Encerrar turma'),
              ),
              if (!readiness.canClose) ...[
                const SizedBox(height: 8),
                const Text(
                  'O botão será liberado quando o servidor confirmar que não há bloqueios.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ],
      ],
    );
  }

  Future<void> _confirmAndClose(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar encerramento'),
        content: const Text(
          'Esta ação encerra a turma institucionalmente. Ela não emite certificados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar encerramento'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.submit();
    }
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Icon(ok ? Icons.check_circle_outline : Icons.pending_outlined),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(title),
        subtitle: Text(message),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

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
                Icon(icon, size: 44),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                if (action != null) ...[const SizedBox(height: 16), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
