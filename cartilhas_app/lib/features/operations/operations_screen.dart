import 'package:flutter/material.dart';
import 'operations_controller.dart';
import 'operations_models.dart';

/// Unrouted candidate. The host owns the controller and session lifecycle.
class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key, required this.controller});
  final OperationsController controller;
  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  final _query = TextEditingController();
  final _reason = TextEditingController();
  final _name = TextEditingController();
  final _cpf = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  late int _generation;
  OperationScope? _scope;
  OperationsController get controller => widget.controller;
  List<TextEditingController> get _inputs => [
    _query,
    _reason,
    _name,
    _cpf,
    _phone,
    _password,
  ];

  @override
  void initState() {
    super.initState();
    _generation = controller.sessionGeneration;
    _scope = controller.scope;
    controller.addListener(_changed);
    controller.load();
  }

  @override
  void didUpdateWidget(OperationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_changed);
      for (final input in _inputs) {
        input.clear();
      }
      _creating = false;
      _generation = controller.sessionGeneration;
      _scope = controller.scope;
      controller.addListener(_changed);
      controller.load();
    }
  }

  void _changed() {
    if (!mounted) return;
    if (_generation != controller.sessionGeneration ||
        _scope != controller.scope) {
      for (final input in _inputs) {
        input.clear();
      }
      _creating = false;
      _generation = controller.sessionGeneration;
      _scope = controller.scope;
    }
    setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    for (final input in _inputs) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    final registration = OperationRegistration(
      name: _name.text.trim(),
      cpf: _cpf.text.trim(),
      phone: _phone.text.trim(),
      password: _password.text,
    );
    final future = controller.register(registration, _reason.text);
    _password.clear();
    _cpf.clear();
    _phone.clear();
    await future;
    if (mounted && controller.snapshot != null && !controller.canRetry) {
      setState(() {
        _creating = false;
        _name.clear();
      });
    }
  }

  Future<void> _revoke() async {
    final selected = controller.snapshot;
    if (selected == null) return;
    final generation = controller.sessionGeneration;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revogar vínculo com esta turma?'),
        content: Text(
          '${selected.person.name}\n${selected.scope.label}\n'
          'A pessoa e o histórico serão preservados. Confira o motivo antes de confirmar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar revogação'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        generation == controller.sessionGeneration &&
        identical(selected, controller.snapshot)) {
      await controller.revoke(_reason.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = controller.snapshot;
    final editable = controller.canNavigate;
    return Scaffold(
      appBar: AppBar(title: const Text('Operação de participantes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.isSimulation)
            const Text(
              'DEMONSTRAÇÃO — use somente dados sintéticos. Nenhum serviço real está conectado.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          const Text(
            'Escolha o contexto, localize ou cadastre a pessoa e confira os vínculos. '
            'O serviço autorizado decide cada operação.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: editable ? controller.load : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Recarregar contextos'),
            ),
          ),
          DropdownButton<OperationScope>(
            key: const ValueKey('operation-scope'),
            isExpanded: true,
            value: controller.scope,
            hint: const Text('Selecionar programa / curso / turma'),
            items: controller.scopes
                .map(
                  (scope) => DropdownMenuItem(
                    value: scope,
                    child: Text(scope.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: editable
                ? (value) {
                    if (value != null) controller.selectScope(value);
                  }
                : null,
          ),
          if (controller.busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Consultando serviço',
            ),
          if (controller.message != null)
            Semantics(liveRegion: true, child: Text(controller.message!)),
          if (controller.canRetry)
            FilledButton(
              onPressed: controller.retry,
              child: const Text('Retomar a mesma operação'),
            ),
          if (controller.scope != null) ...[
            TextField(
              controller: _query,
              enabled: editable,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Buscar pessoa'),
              onSubmitted: editable ? controller.search : null,
            ),
            OutlinedButton(
              onPressed: editable ? () => controller.search(_query.text) : null,
              child: const Text('Localizar'),
            ),
            for (final person in controller.people)
              ListTile(
                title: Text(person.name),
                subtitle: Text('Referência: ${person.id}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: editable ? () => controller.selectPerson(person) : null,
              ),
            TextButton(
              onPressed: editable
                  ? () {
                      if (!_creating) controller.beginRegistration();
                      setState(() => _creating = !_creating);
                    }
                  : null,
              child: Text(
                _creating ? 'Cancelar novo cadastro' : 'Cadastrar nova pessoa',
              ),
            ),
            TextField(
              controller: _reason,
              enabled: editable,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Motivo da operação',
                helperText:
                    'Não informe CPF, senha ou informações socioeconômicas no motivo.',
              ),
            ),
            if (_creating) ...[
              const Text(
                'Confirme que a pessoa não possui cadastro. O serviço verificará duplicidade e permissão.',
              ),
              TextField(
                controller: _name,
                enabled: editable,
                maxLength: 240,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: _cpf,
                enabled: editable,
                keyboardType: TextInputType.number,
                maxLength: 14,
                decoration: const InputDecoration(labelText: 'CPF'),
              ),
              TextField(
                controller: _phone,
                enabled: editable,
                keyboardType: TextInputType.phone,
                maxLength: 32,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              TextField(
                controller: _password,
                enabled: editable,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Senha inicial'),
              ),
              FilledButton(
                onPressed: editable ? _register : null,
                child: const Text('Solicitar cadastro'),
              ),
            ],
            if (selected != null && !_creating) ...[
              const Divider(),
              Text(
                selected.person.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Matrícula no curso: ${selected.enrolled ? "ativa" : "ausente"}',
              ),
              Text(
                'Vínculo com a turma: ${selected.assigned ? "ativo" : "inativo ou ausente"}',
              ),
              if (selected.enrolled && selected.assigned)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      controller.isSimulation
                          ? 'Confirmação final da simulação: matrícula e vínculo à turma ativos neste contexto.'
                          : 'Confirmação final: matrícula e vínculo à turma confirmados pelo serviço autorizado.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              Text(switch (selected.baselineLinked) {
                true => 'Baseline: vínculo informado pelo serviço',
                false => 'Baseline: pendente; não impede matrícula ou estudo',
                null => 'Baseline: situação desconhecida',
              }),
              if (!selected.enrolled)
                FilledButton(
                  onPressed: editable
                      ? () => controller.enroll(_reason.text)
                      : null,
                  child: const Text('Solicitar matrícula'),
                ),
              if (selected.enrolled && !selected.assigned)
                FilledButton(
                  onPressed: editable
                      ? () => controller.assign(_reason.text)
                      : null,
                  child: const Text('Vincular à turma'),
                ),
              if (selected.assigned)
                OutlinedButton(
                  onPressed: editable ? _revoke : null,
                  child: const Text('Revogar vínculo'),
                ),
              const Text(
                'Para corrigir a turma: revogue o vínculo incorreto com motivo e selecione '
                'o novo contexto. A matrícula e o histórico não devem ser apagados.',
              ),
              Text(
                'Histórico deste contexto',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (selected.history.isEmpty)
                const Text('Nenhum registro retornado para este contexto.'),
              for (final entry in selected.history)
                ListTile(
                  title: Text(entry.action),
                  subtitle: Text(
                    '${entry.reason}\n${entry.actorLabel} · ${entry.occurredAt.toUtc().toIso8601String()}',
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
