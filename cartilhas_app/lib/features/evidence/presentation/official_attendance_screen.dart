import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../data/evidence_repository.dart';
import '../models/evidence_models.dart';

class OfficialAttendanceScreen extends StatefulWidget {
  const OfficialAttendanceScreen({
    super.key,
    required this.gateway,
    required this.classId,
    required this.sessionId,
    required this.userId,
  });
  final EvidenceGateway gateway;
  final String classId, sessionId, userId;
  @override
  State<OfficialAttendanceScreen> createState() =>
      _OfficialAttendanceScreenState();
}

class _OfficialAttendanceScreenState extends State<OfficialAttendanceScreen> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  List<OfficialAttendanceDecision> _history = [];
  List<EvidenceSession> _sessions = [];
  int _total = 0, _sessionTotal = 0, _epoch = 0;
  bool _busy = false, _canDecide = false;
  String? _status, _makeup, _error;
  OfficialAttendanceGateway get _gateway =>
      widget.gateway as OfficialAttendanceGateway;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OfficialAttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gateway != widget.gateway ||
        oldWidget.classId != widget.classId ||
        oldWidget.sessionId != widget.sessionId ||
        oldWidget.userId != widget.userId) {
      _epoch++;
      _busy = false;
      _history = [];
      _sessions = [];
      _canDecide = false;
      _status = null;
      _makeup = null;
      _reason.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _epoch++;
    _reason.dispose();
    super.dispose();
  }

  bool _current(int epoch) => mounted && epoch == _epoch;
  void _fail(Object error) {
    _error = error is EvidenceApiException
        ? error.message
        : 'Consulta indisponível. Confira sua conexão e tente novamente.';
    _canDecide = false;
    if (error is EvidenceApiException &&
        {401, 403}.contains(error.statusCode)) {
      _history = [];
      _sessions = [];
    }
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _error = null;
      _canDecide = false;
    });
    try {
      final page = await _gateway.attendanceHistory(
        widget.classId,
        widget.sessionId,
        widget.userId,
        offset: more ? _history.length : 0,
      );
      if (!_current(epoch)) return;
      final sessions = page.canDecide
          ? await _gateway.attendanceSessions(widget.classId)
          : null;
      if (!_current(epoch)) return;
      setState(() {
        _history = [if (more) ..._history, ...page.items];
        _total = page.total;
        _canDecide = page.canDecide;
        _sessions = sessions?.sessions ?? [];
        _sessionTotal = sessions?.total ?? 0;
        if (!_sessions.any((meeting) => meeting.id == _makeup)) _makeup = null;
      });
    } on Object catch (error) {
      if (_current(epoch)) setState(() => _fail(error));
    } finally {
      if (_current(epoch)) setState(() => _busy = false);
    }
  }

  Future<void> _moreSessions() async {
    final epoch = _epoch;
    setState(() => _busy = true);
    try {
      final page = await _gateway.attendanceSessions(
        widget.classId,
        offset: _sessions.length,
      );
      if (_current(epoch)) setState(() => _sessions.addAll(page.sessions));
    } on Object catch (error) {
      if (_current(epoch)) setState(() => _fail(error));
    } finally {
      if (_current(epoch)) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_canDecide || _busy || !_form.currentState!.validate()) return;
    final epoch = _epoch;
    final revision = _history.isEmpty ? 0 : _history.first.revision;
    final reason = _reason.text.trim();
    final key = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              widget.classId,
              widget.sessionId,
              widget.userId,
              revision,
              _status,
              _makeup,
              reason,
            ]),
          ),
        )
        .toString();
    setState(() => _busy = true);
    try {
      await _gateway.decideAttendance(
        classId: widget.classId,
        sessionId: widget.sessionId,
        userId: widget.userId,
        status: _status!,
        expectedRevision: revision,
        reason: reason,
        idempotencyKey: 'attendance:$key',
        makeupSessionId: _makeup,
      );
      if (!_current(epoch)) return;
      setState(() => _busy = false);
      _reason.clear();
      await _load();
    } on Object catch (error) {
      if (_current(epoch)) setState(() => _fail(error));
    } finally {
      if (_current(epoch)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Frequência oficial')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Correções preservam o registro original. Reposição pendente não conta como presença. Somente o instrutor pode decidir com justificativa e conexão.',
        ),
        TextButton(
          onPressed: _busy ? null : _load,
          child: const Text('Atualizar histórico'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, key: const Key('attendance-error')),
        if (!_busy && _history.isEmpty && _error == null)
          const Text(
            'Nenhuma correção oficial. O registro de presença original permanece como referência.',
          ),
        if (_canDecide)
          Form(
            key: _form,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('status-$_epoch'),
                  isExpanded: true,
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Decisão oficial',
                  ),
                  items: [
                    for (final status in [
                      'VALID',
                      'ABSENT',
                      'JUSTIFIED_ABSENCE',
                      'PENDING_MAKEUP',
                    ])
                      DropdownMenuItem(
                        value: status,
                        child: Text(attendanceLabel(status)),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _status = value),
                  validator: (value) =>
                      value == null ? 'Escolha a decisão.' : null,
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('makeup-$_epoch-$_makeup'),
                  isExpanded: true,
                  initialValue: _makeup,
                  decoration: const InputDecoration(
                    labelText: 'Encontro de reposição',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sem reposição'),
                    ),
                    for (final meeting in _sessions.where(
                      (item) => item.id != widget.sessionId,
                    ))
                      DropdownMenuItem(
                        value: meeting.id,
                        child: Text(
                          '${meeting.startsAt.toLocal()} • ${meeting.status}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _makeup = value),
                  validator: (value) =>
                      _status == 'PENDING_MAKEUP' && value == null
                      ? 'Selecione o encontro de reposição.'
                      : null,
                ),
                if (_sessions.length < _sessionTotal)
                  TextButton(
                    onPressed: _busy ? null : _moreSessions,
                    child: const Text('Carregar mais encontros'),
                  ),
                TextFormField(
                  controller: _reason,
                  enabled: !_busy,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da decisão',
                    helperText: 'Sem dados sensíveis desnecessários.',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Informe o motivo.'
                      : null,
                ),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Registrar decisão oficial'),
                ),
              ],
            ),
          ),
        for (final row in _history)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revisão ${row.revision} • ${attendanceLabel(row.status)}',
                  ),
                  Text(row.reason),
                  Text(row.decidedAt),
                  if (row.makeupSessionId != null)
                    Text('Reposição vinculada: ${row.makeupSessionId}'),
                ],
              ),
            ),
          ),
        if (_history.length < _total)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Carregar histórico anterior'),
          ),
      ],
    ),
  );
}

String attendanceLabel(String status) => switch (status) {
  'VALID' => 'Presença válida',
  'ABSENT' => 'Ausência',
  'JUSTIFIED_ABSENCE' => 'Ausência justificada',
  'PENDING_MAKEUP' => 'Reposição pendente',
  _ => 'Estado desconhecido',
};
