import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../data/classroom_repository.dart';
import '../models/classroom_models.dart';

class StudentFollowupScreen extends StatefulWidget {
  const StudentFollowupScreen({
    super.key,
    required this.repository,
    required this.classroom,
    required this.students,
    required this.staffId,
  });
  final ClassroomRepository repository;
  final ClassroomDetails classroom;
  final List<ClassroomStudent> students;
  final String staffId;
  @override
  State<StudentFollowupScreen> createState() => _StudentFollowupScreenState();
}

class _StudentFollowupScreenState extends State<StudentFollowupScreen> {
  String? _student, _error;
  Map<String, dynamic>? _baseline;
  List<Map<String, dynamic>> _cases = [];
  bool _busy = false, _ready = false;
  int _total = 0;

  Future<void> _load({bool more = false}) async {
    if (_student == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _ready = false;
      if (!more) {
        _baseline = null;
        _cases = [];
      }
    });
    try {
      final baseline = await widget.repository.studentBaseline(
        widget.classroom.id,
        _student!,
      );
      final cases = await widget.repository.mentorshipCases(
        widget.classroom.id,
        _student!,
        offset: _cases.length,
      );
      if (!mounted) return;
      setState(() {
        _baseline = baseline['baseline'] as Map<String, dynamic>?;
        _cases = [
          ..._cases,
          ...(cases['items'] as List).cast<Map<String, dynamic>>(),
        ];
        _total = cases['total'] as int;
        _ready = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _baseline = null;
          _cases = [];
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _key(String action, Map<String, String> values, int revision) =>
      'followup-${sha256.convert(utf8.encode(jsonEncode([widget.classroom.id, _student, action, revision, values])))}';

  Future<Map<String, String>?> _form(
    String title,
    Map<String, String> values,
    Map<String, String> labels, {
    bool baseline = false,
  }) async {
    final controllers = values.map(
      (key, value) => MapEntry(key, TextEditingController(text: value)),
    );
    final form = GlobalKey<FormState>();
    var confirmed = false;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Aluno: ${widget.students.firstWhere((s) => s.userId == _student).name}\nRegistre somente contexto pedagógico necessário, sem dados sensíveis.',
                    ),
                    for (final entry in controllers.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: entry.key == 'status'
                            ? DropdownButtonFormField<String>(
                                initialValue: entry.value.text,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: labels[entry.key],
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'open',
                                    child: Text('Aberta'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'in_progress',
                                    child: Text('Em acompanhamento'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'closed',
                                    child: Text('Encerrada'),
                                  ),
                                ],
                                onChanged: (value) => entry.value.text = value!,
                              )
                            : TextFormField(
                                controller: entry.value,
                                decoration: InputDecoration(
                                  labelText: labels[entry.key],
                                ),
                                maxLength: entry.key == 'reason'
                                    ? 500
                                    : (entry.key == 'objective' ||
                                          entry.key == 'next_action')
                                    ? 1000
                                    : 240,
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (entry.key == 'territory_id') return null;
                                  if (text.isEmpty) {
                                    return 'Preencha este campo.';
                                  }
                                  if ([
                                        'reason',
                                        'objective',
                                        'next_action',
                                      ].contains(entry.key) &&
                                      text.length < 3) {
                                    return 'Use pelo menos 3 caracteres.';
                                  }
                                  if (entry.key == 'baseline_date') {
                                    final date = DateTime.tryParse(text);
                                    if (date == null ||
                                        !RegExp(
                                          r'^\d{4}-\d{2}-\d{2}$',
                                        ).hasMatch(text) ||
                                        date.toIso8601String().substring(
                                              0,
                                              10,
                                            ) !=
                                            text) {
                                      return 'Use uma data válida: AAAA-MM-DD.';
                                    }
                                  }
                                  return null;
                                },
                              ),
                      ),
                    if (baseline)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: confirmed,
                        onChanged: (value) =>
                            update(() => confirmed = value ?? false),
                        title: const Text(
                          'Conferi que este formulário pertence ao aluno selecionado.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: baseline && !confirmed
                  ? null
                  : () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(
                          context,
                          controllers.map(
                            (key, controller) =>
                                MapEntry(key, controller.text.trim()),
                          ),
                        );
                      }
                    },
              child: const Text('Salvar online'),
            ),
          ],
        ),
      ),
    );
    // The dialog route may still be animating out; controllers are disposed after it.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _saveBaseline() async {
    final revision = _baseline?['revision'] as int? ?? 0;
    final values = await _form(
      'Vincular baseline',
      {
        'source': _baseline?['source'] as String? ?? 'baseline-tablet',
        'record_id': _baseline?['record_id'] as String? ?? '',
        'baseline_date': _baseline?['baseline_date'] as String? ?? '',
        'territory_id': _baseline?['territory_id'] as String? ?? '',
        'reason': '',
      },
      {
        'source': 'Origem do formulário',
        'record_id': 'ID local do registro',
        'baseline_date': 'Data da coleta (AAAA-MM-DD)',
        'territory_id': 'Território (opcional)',
        'reason': 'Justificativa da vinculação',
      },
      baseline: true,
    );
    if (values == null || !mounted) return;
    await _write(
      () => widget.repository.saveStudentBaseline(
        classId: widget.classroom.id,
        userId: _student!,
        source: values['source']!,
        recordId: values['record_id']!,
        baselineDate: values['baseline_date']!,
        territoryId: values['territory_id']!.isEmpty
            ? null
            : values['territory_id'],
        expectedRevision: revision,
        reason: values['reason']!,
        idempotencyKey: _key('baseline', values, revision),
      ),
    );
  }

  Future<void> _editCase([Map<String, dynamic>? item]) async {
    final values = await _form(
      item == null ? 'Abrir mentoria' : 'Atualizar mentoria',
      {
        'mentor_id': item?['mentor_id'] as String? ?? widget.staffId,
        'objective': item?['objective'] as String? ?? '',
        'next_action': item?['next_action'] as String? ?? '',
        if (item != null) 'status': item['status'] as String,
        'reason': '',
      },
      {
        'mentor_id': 'ID do responsável da equipe',
        'objective': 'Objetivo',
        'next_action': 'Próxima ação',
        'status': 'Situação',
        'reason': 'Justificativa',
      },
    );
    if (values == null || !mounted) return;
    final revision = item?['revision'] as int? ?? 0;
    final key = _key(
      item?['id'] as String? ?? 'new-mentorship',
      values,
      revision,
    );
    await _write(
      () => item == null
          ? widget.repository.openMentorship(
              classId: widget.classroom.id,
              userId: _student!,
              mentorId: values['mentor_id']!,
              objective: values['objective']!,
              nextAction: values['next_action']!,
              reason: values['reason']!,
              idempotencyKey: key,
            )
          : widget.repository.updateMentorship(
              classId: widget.classroom.id,
              caseId: item['id'] as String,
              expectedRevision: revision,
              mentorId: values['mentor_id']!,
              objective: values['objective']!,
              nextAction: values['next_action']!,
              status: values['status']!,
              reason: values['reason']!,
              idempotencyKey: key,
            ),
    );
  }

  Future<void> _write(Future<Object?> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error =
              '$error\nAtualize para conferir o estado antes de tentar novamente.';
          _ready = false;
          _baseline = null;
          _cases = [];
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Acompanhamento do aluno')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.classroom.name,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Baseline e mentoria são registros da equipe. Não alteram o formulário original.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _student,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Aluno da turma'),
          items: widget.students
              .map(
                (s) => DropdownMenuItem(value: s.userId, child: Text(s.name)),
              )
              .toList(),
          onChanged: _busy
              ? null
              : (value) {
                  _student = value;
                  _load();
                },
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_student != null)
          TextButton(
            onPressed: _busy ? null : () => _load(),
            child: const Text('Atualizar acompanhamento'),
          ),
        if (_ready) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _baseline == null
                        ? 'Baseline ainda não vinculado'
                        : 'Baseline vinculado',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_baseline != null)
                    Text(
                      '${_baseline!['source']} • ${_baseline!['record_id']}\nColeta: ${_baseline!['baseline_date']}',
                    ),
                  TextButton(
                    onPressed: _busy ? null : _saveBaseline,
                    child: const Text('Conferir vínculo do baseline'),
                  ),
                ],
              ),
            ),
          ),
          FilledButton.tonal(
            onPressed: _busy ? null : () => _editCase(),
            child: const Text('Abrir mentoria'),
          ),
          if (_cases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhuma mentoria registrada.'),
            ),
          for (final item in _cases)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['objective'] as String,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Responsável: ${item['mentor_name'] ?? 'Não disponível'}\nPróxima ação: ${item['next_action']}',
                    ),
                    Text(switch (item['status']) {
                      'open' => 'Aberta',
                      'in_progress' => 'Em acompanhamento',
                      'closed' => 'Encerrada',
                      _ => 'Situação desconhecida',
                    }),
                    TextButton(
                      onPressed: _busy ? null : () => _editCase(item),
                      child: const Text('Atualizar mentoria'),
                    ),
                  ],
                ),
              ),
            ),
          if (_cases.length < _total)
            TextButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('Carregar mais'),
            ),
        ],
      ],
    ),
  );
}
