import 'package:flutter/material.dart';

import '../data/checkin_draft_store.dart';
import '../data/evidence_repository.dart';
import '../models/evidence_models.dart';

class EvidenceCheckinScreen extends StatefulWidget {
  const EvidenceCheckinScreen({
    super.key,
    required this.gateway,
    this.draftStore,
  });

  final EvidenceGateway gateway;
  final CheckinDraftStore? draftStore;

  @override
  State<EvidenceCheckinScreen> createState() => _EvidenceCheckinScreenState();
}

class _EvidenceCheckinScreenState extends State<EvidenceCheckinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _classId = TextEditingController();
  final _sessionId = TextEditingController();
  final _token = TextEditingController();
  String _kind = 'checkin';
  bool _busy = false;
  String? _error;
  EvidenceCheckin? _result;
  late String _idempotencyKey = _newIdempotencyKey();
  late final CheckinDraftStore _draftStore;
  CheckinDraft? _pendingDraft;

  @override
  void initState() {
    super.initState();
    _draftStore = widget.draftStore ?? SharedPreferencesCheckinDraftStore();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final draft = await _draftStore.read();
    if (!mounted || draft == null) return;
    setState(() {
      _pendingDraft = draft;
      _classId.text = draft.classId;
      _sessionId.text = draft.sessionId;
      _kind = draft.kind;
      _idempotencyKey = draft.idempotencyKey;
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _classId.dispose();
    _sessionId.dispose();
    _token.dispose();
    final gateway = widget.gateway;
    if (gateway is EvidenceRepository) gateway.dispose();
    super.dispose();
  }

  Future<bool> _parseCode() async {
    final raw = _code.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'tutortds' || uri.host != 'checkin') {
      setState(() => _error = 'Código incompleto. Confira com a equipe.');
      return false;
    }
    final classId = uri.queryParameters['class_id'] ?? '';
    final sessionId = uri.queryParameters['session_id'] ?? '';
    final token = uri.queryParameters['token'] ?? '';
    if (classId.isEmpty || sessionId.isEmpty || token.isEmpty) {
      setState(() => _error = 'Código incompleto. Confira com a equipe.');
      return false;
    }
    final resumesPending =
        _pendingDraft == null ||
        (_pendingDraft!.classId == classId &&
            _pendingDraft!.sessionId == sessionId &&
            _pendingDraft!.kind == _kind);
    setState(() {
      if (!resumesPending) {
        _pendingDraft = null;
        _idempotencyKey = _newIdempotencyKey();
      }
      _classId.text = classId;
      _sessionId.text = sessionId;
      _token.text = token;
      _error = null;
    });
    if (!resumesPending) await _draftStore.clear();
    return true;
  }

  Future<void> _submit() async {
    if (!await _parseCode()) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.gateway.checkin(
        classId: _classId.text,
        sessionId: _sessionId.text,
        kind: _kind,
        idempotencyKey: _idempotencyKey,
        token: _token.text,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _pendingDraft = null;
        _idempotencyKey = _newIdempotencyKey();
        _code.clear();
        _token.clear();
      });
      await _draftStore.clear();
    } on EvidenceApiException catch (error) {
      if (error.isNetworkFailure) {
        final draft = CheckinDraft(
          classId: _classId.text,
          sessionId: _sessionId.text,
          kind: _kind,
          idempotencyKey: _idempotencyKey,
          createdAt: DateTime.now().toUtc(),
        );
        await _draftStore.write(draft);
        if (mounted) setState(() => _pendingDraft = draft);
      }
      if (mounted) setState(() => _error = error.toString());
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registrar presença')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Check-in seguro',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cole o código exibido pela equipe. O app identifica apenas sua conta e nunca mostra a lista da turma.',
        ),
        const SizedBox(height: 12),
        if (_pendingDraft != null)
          Card.filled(
            key: const ValueKey('pending-checkin'),
            child: const ListTile(
              leading: Icon(Icons.pending_actions_outlined),
              title: Text('Presença pendente neste aparelho'),
              subtitle: Text(
                'A confirmação não foi enviada. Cole um código atual da mesma sessão para tentar novamente; o código anterior não foi salvo.',
              ),
            ),
          ),
        if (_pendingDraft != null) const SizedBox(height: 12),
        Card.filled(
          child: const ListTile(
            leading: Icon(Icons.wifi_outlined),
            title: Text('Conexão necessária'),
            subtitle: Text(
              'O código é temporário, não é salvo no aparelho e só há confirmação após sincronizar.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _code,
                minLines: 2,
                maxLines: 4,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Código completo da sessão',
                  hintText: 'tutortds://checkin?...',
                  prefixIcon: Icon(Icons.qr_code_2),
                  border: OutlineInputBorder(),
                ),
                validator: (_) =>
                    _classId.text.trim().isEmpty ||
                        _sessionId.text.trim().isEmpty ||
                        _token.text.trim().isEmpty
                    ? 'Informe um código válido.'
                    : null,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'checkin', label: Text('Entrada')),
                  ButtonSegment(value: 'checkout', label: Text('Saída')),
                ],
                selected: {_kind},
                onSelectionChanged: _busy
                    ? null
                    : (values) {
                        setState(() {
                          _kind = values.first;
                          _pendingDraft = null;
                          _idempotencyKey = _newIdempotencyKey();
                        });
                        _draftStore.clear();
                      },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: const Icon(Icons.how_to_reg_outlined),
                label: Text(
                  _busy
                      ? 'Sincronizando...'
                      : _kind == 'checkin'
                      ? 'Confirmar entrada'
                      : 'Confirmar saída',
                ),
              ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.sync_problem_outlined),
              title: const Text('Não sincronizado'),
              subtitle: Text(
                _pendingDraft == null
                    ? _error!
                    : '$_error Seu registro está pendente, não confirmado. Tente novamente com conexão; se o app for fechado, obtenha um novo código.',
              ),
            ),
          ),
        if (_result != null)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text(
                _result!.kind == 'checkin'
                    ? 'Entrada confirmada'
                    : 'Saída confirmada',
              ),
              subtitle: Text(
                '${_dateTime(_result!.occurredAt)} • evidência ${_result!.evidenceId}',
              ),
            ),
          ),
      ],
    ),
  );
}

String _newIdempotencyKey() =>
    'mobile:${DateTime.now().microsecondsSinceEpoch}';

String _dateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
