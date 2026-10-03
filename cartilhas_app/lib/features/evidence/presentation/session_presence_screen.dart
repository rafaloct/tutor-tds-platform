import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../analytics/app_telemetry_service.dart';
import '../data/evidence_repository.dart';
import '../models/evidence_models.dart';
import 'official_attendance_screen.dart';

class SessionPresenceScreen extends StatefulWidget {
  const SessionPresenceScreen({
    super.key,
    required this.gateway,
    required this.classId,
    required this.sessionId,
  });
  final EvidenceGateway gateway;
  final String classId, sessionId;
  @override
  State<SessionPresenceScreen> createState() => _SessionPresenceScreenState();
}

class _SessionPresenceScreenState extends State<SessionPresenceScreen> {
  List<SessionPresence> _items = const [];
  int _total = 0;
  bool _busy = false;
  bool _open = false;
  String? _error;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SessionPresenceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gateway != widget.gateway ||
        oldWidget.classId != widget.classId ||
        oldWidget.sessionId != widget.sessionId) {
      _epoch++;
      _items = const [];
      _total = 0;
      _open = false;
      _busy = false;
      _load();
    }
  }

  bool _current(int epoch) => mounted && epoch == _epoch;

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _error = null;
      if (!more) {
        _items = const [];
        _open = false;
        _total = 0;
      }
    });
    try {
      final page = await widget.gateway.presence(
        widget.classId,
        widget.sessionId,
        offset: more ? _items.length : 0,
      );
      if (!_current(epoch)) return;
      setState(() {
        _items = [..._items, ...page.items];
        _total = page.total;
        _open = page.sessionStatus == 'open';
      });
    } on Object catch (error) {
      if (_current(epoch)) _showError(error);
    } finally {
      if (_current(epoch)) setState(() => _busy = false);
    }
  }

  void _showError(Object error) => setState(() {
    _error = error is EvidenceApiException
        ? error.message
        : 'Não foi possível consultar a presença. Tente novamente.';
    if (error is EvidenceApiException &&
        {401, 403}.contains(error.statusCode)) {
      _items = const [];
      _total = 0;
      _open = false;
    }
  });

  Future<void> _decide(SessionPresence row) async {
    final epoch = _epoch;
    final decision = await showDialog<_Decision>(
      context: context,
      builder: (_) => _PresenceDialog(name: row.userName),
    );
    if (decision == null || !_current(epoch)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Stable retry identity; no offline storage or optimistic confirmation.
      final key = sha256
          .convert(
            utf8.encode(
              jsonEncode([
                widget.classId,
                widget.sessionId,
                row.userId,
                row.revision,
                decision.status,
                decision.reason,
              ]),
            ),
          )
          .toString();
      await widget.gateway.decidePresence(
        classId: widget.classId,
        sessionId: widget.sessionId,
        userId: row.userId,
        status: decision.status,
        expectedRevision: row.revision,
        reason: decision.reason,
        idempotencyKey: 'presence:$key',
      );
      if (!mounted || !_current(epoch)) return;
      try {
        await Provider.of<AppTelemetryService?>(
          context,
          listen: false,
        )?.trackFeature(featureId: 'presence_decision_recorded');
      } on Object {
        /* Optional analytics never changes the domain decision. */
      }
      if (!_current(epoch)) return;
      setState(() => _busy = false);
      await _load();
    } on Object catch (error) {
      if (_current(epoch)) _showError(error);
    } finally {
      if (_current(epoch)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conferir presença')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'QR e atividade são indícios, não confirmação. A equipe decide a presença de cada participante, com justificativa e conexão.',
        ),
        TextButton.icon(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Atualizar presença'),
        ),
        if (_error != null) Text(_error!, key: const Key('presence-error')),
        if (!_busy && !_open && _error == null)
          const Text('Sessão encerrada: decisões somente para consulta.'),
        if (!_busy && _items.isEmpty && _error == null)
          const Text('Nenhum participante disponível nesta consulta.'),
        for (final row in _items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.userName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    _label(row.status),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Entradas: ${row.checkinCount} • Saídas: ${row.checkoutCount} • Atividades: ${row.activityCount}',
                  ),
                  if (row.reason != null) Text('Justificativa: ${row.reason}'),
                  if (widget.gateway is OfficialAttendanceGateway)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => OfficialAttendanceScreen(
                                  gateway: widget.gateway,
                                  classId: widget.classId,
                                  sessionId: widget.sessionId,
                                  userId: row.userId,
                                ),
                              ),
                            ),
                      child: const Text('Frequência oficial e reposição'),
                    ),
                  if (_open)
                    OutlinedButton(
                      onPressed: _busy ? null : () => _decide(row),
                      child: const Text('Registrar decisão'),
                    ),
                ],
              ),
            ),
          ),
        if (_items.length < _total)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: const Text('Carregar mais participantes'),
          ),
        if (_busy) const Center(child: CircularProgressIndicator()),
      ],
    ),
  );
}

String _label(String status) => switch (status) {
  'suggested_present' => 'Indício de presença — aguarda conferência',
  'confirmed_present' => 'Presença confirmada pela equipe',
  'justified_absence' => 'Ausência justificada',
  'absent' => 'Ausência registrada pela equipe',
  _ => 'Aguardando conferência',
};

class _Decision {
  const _Decision(this.status, this.reason);
  final String status, reason;
}

class _PresenceDialog extends StatefulWidget {
  const _PresenceDialog({required this.name});
  final String name;
  @override
  State<_PresenceDialog> createState() => _PresenceDialogState();
}

class _PresenceDialogState extends State<_PresenceDialog> {
  String? _status;
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Conferência humana'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Participante: ${widget.name}. Registre somente o motivo necessário, sem informação de saúde ou outros dados sensíveis.',
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Decisão'),
              items: [
                for (final status in [
                  'confirmed_present',
                  'justified_absence',
                  'absent',
                ])
                  DropdownMenuItem(
                    value: status,
                    child: Text(
                      _label(status),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => _status = value,
              validator: (value) => value == null ? 'Escolha a decisão.' : null,
            ),
            TextFormField(
              controller: _reason,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Justificativa'),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Informe uma justificativa.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _Decision(_status!, _reason.text.trim()));
          }
        },
        child: const Text('Confirmar decisão'),
      ),
    ],
  );
}
