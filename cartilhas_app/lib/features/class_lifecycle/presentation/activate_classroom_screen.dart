import 'package:flutter/material.dart';

import '../application/class_lifecycle_controller.dart';
import '../data/class_lifecycle_gateway.dart';

class ActivateClassroomScreen extends StatefulWidget {
  const ActivateClassroomScreen({super.key, required this.gateway});

  final ClassLifecycleGateway gateway;

  @override
  State<ActivateClassroomScreen> createState() => _ActivateClassroomScreenState();
}

class _ActivateClassroomScreenState extends State<ActivateClassroomScreen> {
  late final ActivateClassroomController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ActivateClassroomController(widget.gateway)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Ativar turma')),
      body: _controller.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_controller.bootstrap == null) ...[
                  Text(_controller.error ?? 'Não foi possível consultar as turmas.'),
                  TextButton(
                    onPressed: _controller.load,
                    child: const Text('Tentar novamente'),
                  ),
                ] else if (_controller.result != null) ...[
                  const Text('Turma ativada'),
                  Text('Situação: ${_controller.result!.statusLabel}.'),
                ] else if (_controller.plannedClasses.isEmpty)
                  const Text('Nenhuma turma planejada disponível neste contexto.')
                else ...[
                  const Text(
                    'Confira a preparação da turma. O servidor confirma se ela pode ser ativada.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('activate-class-${_controller.selectedClassId}'),
                    initialValue: _controller.selectedClassId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Turma planejada'),
                    items: _controller.plannedClasses
                        .map((item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(growable: false),
                    onChanged: _controller.busy ? null : _controller.selectClass,
                  ),
                  TextButton.icon(
                    onPressed: _controller.busy
                        ? null
                        : _controller.refreshReadiness,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar prontidão'),
                  ),
                  if (_controller.busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (_controller.error != null) ...[
                    const SizedBox(height: 12),
                    Text(_controller.error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  if (_controller.readiness != null) ...[
                    const SizedBox(height: 16),
                    Text(_controller.readiness!.canActivate
                        ? 'Preparação conferida pelo servidor.'
                        : 'A turma ainda precisa de ajustes antes da ativação.'),
                    for (final blocker in _controller.readiness!.blockers)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('• $blocker'),
                      ),
                    const SizedBox(height: 16),
                    KeyedSubtree(
                      key: ValueKey('activate-reason-${_controller.selectedClassId}'),
                      child: TextFormField(
                        key: const Key('activate_reason'),
                        initialValue: _controller.reason,
                        enabled: _controller.readiness!.canActivate && !_controller.busy,
                        decoration: const InputDecoration(
                          labelText: 'Motivo da ativação',
                          hintText: 'Ex.: local, equipe e oferta conferidos',
                        ),
                        maxLines: 2,
                        onChanged: _controller.setReason,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _controller.canSubmit ? _confirmAndActivate : null,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Ativar turma'),
                    ),
                  ],
                ],
              ],
            ),
    ),
  );

  Future<void> _confirmAndActivate() async {
    final classId = _controller.selectedClassId;
    final className = _controller.readiness?.classroomName;
    if (classId == null || className == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar ativação'),
        content: Text('Ativar "$className"? A turma passará de planejada para em andamento.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar ativação'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        _controller.selectedClassId == classId) {
      await _controller.submit();
    }
  }
}
