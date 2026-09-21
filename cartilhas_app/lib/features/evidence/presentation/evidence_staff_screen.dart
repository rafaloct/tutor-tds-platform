import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../classrooms/models/classroom_models.dart';
import '../data/evidence_repository.dart';
import '../models/evidence_models.dart';
import '../../analytics/telemetry_route.dart';
import 'session_presence_screen.dart';

class EvidenceStaffScreen extends StatefulWidget {
  const EvidenceStaffScreen({
    super.key,
    required this.classroom,
    required this.gateway,
  });

  final ClassroomDetails classroom;
  final EvidenceGateway gateway;

  @override
  State<EvidenceStaffScreen> createState() => _EvidenceStaffScreenState();
}

class _EvidenceStaffScreenState extends State<EvidenceStaffScreen> {
  EvidenceSession? _session;
  EvidenceReport? _report;
  EvidenceImportRecord? _lastImport;
  List<EvidenceExceptionItem> _exceptions = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() => _run(() async {
    final results = await Future.wait<Object?>([
      widget.gateway.openSession(widget.classroom.id),
      widget.gateway.exceptions(widget.classroom.id),
    ]);
    if (!mounted) return;
    setState(() {
      _session = results[0] as EvidenceSession?;
      _exceptions = results[1]! as List<EvidenceExceptionItem>;
    });
  });

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadExceptions() => _run(() async {
    final items = await widget.gateway.exceptions(widget.classroom.id);
    if (mounted) setState(() => _exceptions = items);
  });

  Future<void> _openSession() async {
    final now = DateTime.now();
    await _run(() async {
      final session = await widget.gateway.createSession(
        classId: widget.classroom.id,
        startsAt: now.subtract(const Duration(minutes: 5)),
        endsAt: now.add(const Duration(hours: 2)),
      );
      if (mounted) {
        setState(() {
          _session = session;
          _report = null;
        });
      }
    });
  }

  Future<void> _rotateToken() => _run(() async {
    final session = _session;
    if (session == null) return;
    final updated = await widget.gateway.rotateToken(
      widget.classroom.id,
      session.id,
    );
    if (mounted) setState(() => _session = updated);
  });

  Future<void> _review(EvidenceExceptionItem item, String decision) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          decision == 'accepted' ? 'Motivo da aceitação' : 'Motivo da rejeição',
        ),
        children: [
          for (final value
              in decision == 'accepted'
                  ? const ['verified', 'corrected']
                  : const ['unrelated', 'insufficient', 'duplicate'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(_reasonLabel(value)),
            ),
        ],
      ),
    );
    if (reason == null) return;
    await _run(() async {
      await widget.gateway.review(
        classId: widget.classroom.id,
        evidenceId: item.evidenceId,
        decision: decision,
        reasonCode: reason,
      );
      if (mounted) {
        setState(
          () => _exceptions = _exceptions
              .where((candidate) => candidate.evidenceId != item.evidenceId)
              .toList(growable: false),
        );
      }
    });
  }

  Future<void> _closeSession() async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    EvidenceApiException? conflict;
    try {
      final report = await widget.gateway.closeSession(
        classId: widget.classroom.id,
        sessionId: session.id,
      );
      if (mounted) setState(() => _report = report);
    } on EvidenceApiException catch (error) {
      if (error.statusCode == 409) {
        conflict = error;
      } else if (mounted) {
        setState(() => _error = error.message);
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted || conflict == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pendências antes do fechamento'),
        content: Text(
          'A sessão contém evidências pendentes. Revise as exceções ou confirme que deseja gerar o relatório com essas pendências.\n\n${conflict!.message}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar e revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar pendências'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final report = await widget.gateway.closeSession(
        classId: widget.classroom.id,
        sessionId: session.id,
        confirmPending: true,
      );
      if (mounted) setState(() => _report = report);
    });
  }

  Future<void> _openImportDialog() async {
    final draft = await showDialog<_ImportDraft>(
      context: context,
      builder: (_) => const _EvidenceImportDialog(),
    );
    if (draft == null) return;
    await _run(() async {
      final record = await widget.gateway.createImport(
        classId: widget.classroom.id,
        sourceType: draft.sourceType,
        sourceDigest: draft.sourceDigest,
        idempotencyKey:
            'import:${draft.sourceDigest.substring(0, 16)}:${DateTime.now().millisecondsSinceEpoch}',
        retentionUntil: DateTime.now().add(const Duration(days: 30)),
        items: [
          EvidenceImportItemDraft(
            itemDigest: draft.itemDigest,
            evidenceType: draft.evidenceType,
            occurredAt: draft.occurredAt,
            userId: draft.userId,
            sessionId: draft.sessionId,
            metadata: draft.metadata,
          ),
        ],
      );
      if (mounted) {
        setState(() => _lastImport = record);
        await _loadExceptions();
      }
    });
  }

  Future<void> _refreshImport() => _run(() async {
    final current = _lastImport;
    if (current == null) return;
    final updated = await widget.gateway.getImport(
      widget.classroom.id,
      current.id,
    );
    if (mounted) setState(() => _lastImport = updated);
  });

  Future<void> _refreshReport() => _run(() async {
    final current = _report;
    if (current == null) return;
    final updated = await widget.gateway.report(
      widget.classroom.id,
      current.id,
    );
    if (mounted) setState(() => _report = updated);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Presença e evidências')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.classroom.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Evidências são sinais auditáveis. Presença e conclusão exigem revisão humana.',
          ),
          const SizedBox(height: 12),
          Card.filled(
            child: const ListTile(
              leading: Icon(Icons.cloud_done_outlined),
              title: Text('Registro online'),
              subtitle: Text(
                'Ações exibem confirmação da API. Falhas não ficam em fila local silenciosa.',
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.sync_problem_outlined),
                title: const Text('Não sincronizado'),
                subtitle: Text(_error!),
              ),
            ),
          const SizedBox(height: 12),
          _sessionCard(),
          const SizedBox(height: 16),
          _exceptionsCard(),
          const SizedBox(height: 16),
          _importsCard(),
          if (_report != null) ...[
            const SizedBox(height: 16),
            _ReportCard(report: _report!, onRefresh: _refreshReport),
          ],
        ],
      ),
    );
  }

  Widget _sessionCard() {
    final session = _session;
    final token = session?.checkinToken;
    final qrData = session != null && token != null
        ? Uri(
            scheme: 'tutortds',
            host: 'checkin',
            queryParameters: {
              'class_id': widget.classroom.id,
              'session_id': session.id,
              'token': token,
            },
          ).toString()
        : null;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sessão da turma',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (session == null) ...[
              const Text(
                'Abra uma janela de duas horas para gerar um QR temporário.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _openSession,
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Abrir sessão agora'),
              ),
            ] else ...[
              Text(
                'Estado: ${_report == null && session.status == "open" ? "aberta" : "encerrada"} • token v${session.tokenVersion}',
              ),
              if (token == null &&
                  session.status == 'open' &&
                  _report == null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Sessão recuperada com segurança. O token anterior não é reexibido; rotacione para gerar um novo QR.',
                ),
              ],
              Text(
                'QR válido até ${_dateTime(session.tokenExpiresAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (qrData != null &&
                  session.status == 'open' &&
                  _report == null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Semantics(
                    label: 'QR temporário de check-in da turma',
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Colors.white),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(data: qrData, size: 210),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  'Código da sessão: ${session.id}',
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                            context,
                            trackedRoute(
                              pageId: 'session_presence',
                              featureId: 'session_presence',
                              builder: (_) => SessionPresenceScreen(
                                gateway: widget.gateway,
                                classId: widget.classroom.id,
                                sessionId: session.id,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.how_to_reg),
                    label: const Text('Conferir presença'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _busy || session.status != 'open' || _report != null
                        ? null
                        : _rotateToken,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rotacionar QR'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _busy || session.status != 'open' || _report != null
                        ? null
                        : _closeSession,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Fechar com revisão'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _exceptionsCard() => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Exceções para revisar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Atualizar exceções',
                onPressed: _busy ? null : _loadExceptions,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_exceptions.isEmpty)
            const Text('Nenhuma evidência pendente visível para sua conta.')
          else
            for (final item in _exceptions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Evidência precisa de revisão'),
                subtitle: Text(
                  'ID ${item.evidenceId}${item.userId == null ? "" : " • participante ${item.userId}"}',
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Decidir sobre evidência',
                  onSelected: (decision) => _review(item, decision),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'accepted',
                      child: Text('Aceitar com motivo'),
                    ),
                    PopupMenuItem(
                      value: 'rejected',
                      child: Text('Rejeitar com motivo'),
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );

  Widget _importsCard() => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Importar metadados preparados',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'WhatsApp e Drive aceitam somente digests e metadados estruturados. Não cole conversas, links públicos ou arquivos brutos.',
          ),
          if (_lastImport != null) ...[
            const SizedBox(height: 8),
            Text(
              'Importação ${_lastImport!.status} • ${_lastImport!.evidenceIds.length} item(ns) • retenção até ${_date(_lastImport!.retentionUntil)}',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _refreshImport,
                icon: const Icon(Icons.sync_outlined),
                label: const Text('Consultar status na API'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _openImportDialog,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Informar digests e metadados'),
          ),
        ],
      ),
    ),
  );
}

class _EvidenceImportDialog extends StatefulWidget {
  const _EvidenceImportDialog();

  @override
  State<_EvidenceImportDialog> createState() => _EvidenceImportDialogState();
}

class _EvidenceImportDialogState extends State<_EvidenceImportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sourceDigest = TextEditingController();
  final _itemDigest = TextEditingController();
  final _userId = TextEditingController();
  final _sessionId = TextEditingController();
  final _metadataValue = TextEditingController();
  String _sourceType = 'manual_metadata';
  String _evidenceType = 'observation';
  String _metadataKey = 'source_item_id';

  @override
  void dispose() {
    _sourceDigest.dispose();
    _itemDigest.dispose();
    _userId.dispose();
    _sessionId.dispose();
    _metadataValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Metadados da evidência'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Não informe texto de conversa. Os digests devem ser calculados no preparo autorizado da fonte.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _sourceType,
                decoration: const InputDecoration(labelText: 'Origem'),
                items: const [
                  DropdownMenuItem(
                    value: 'manual_metadata',
                    child: Text('Metadados manuais'),
                  ),
                  DropdownMenuItem(
                    value: 'whatsapp_export',
                    child: Text('Exportação WhatsApp preparada'),
                  ),
                  DropdownMenuItem(
                    value: 'drive_metadata',
                    child: Text('Metadados do Drive preparados'),
                  ),
                  DropdownMenuItem(
                    value: 'sharesheet',
                    child: Text('Compartilhamento preparado'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _sourceType = value ?? 'manual_metadata'),
              ),
              const SizedBox(height: 10),
              _digestField(_sourceDigest, 'Digest SHA-256 da origem'),
              const SizedBox(height: 10),
              _digestField(_itemDigest, 'Digest SHA-256 do item'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _evidenceType,
                decoration: const InputDecoration(labelText: 'Tipo do item'),
                items: const [
                  DropdownMenuItem(
                    value: 'observation',
                    child: Text('Observação'),
                  ),
                  DropdownMenuItem(value: 'activity', child: Text('Atividade')),
                  DropdownMenuItem(
                    value: 'certificate',
                    child: Text('Certificado'),
                  ),
                  DropdownMenuItem(
                    value: 'message_metadata',
                    child: Text('Metadados de mensagem'),
                  ),
                  DropdownMenuItem(
                    value: 'document_metadata',
                    child: Text('Metadados de documento'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _evidenceType = value ?? 'observation'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _userId,
                decoration: const InputDecoration(
                  labelText: 'ID interno do participante (opcional)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _sessionId,
                decoration: const InputDecoration(
                  labelText: 'ID da sessão (opcional)',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _metadataKey,
                decoration: const InputDecoration(
                  labelText: 'Campo estruturado',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'source_item_id',
                    child: Text('ID do item na origem'),
                  ),
                  DropdownMenuItem(
                    value: 'message_count',
                    child: Text('Quantidade de mensagens'),
                  ),
                  DropdownMenuItem(
                    value: 'mime_type',
                    child: Text('Tipo MIME'),
                  ),
                  DropdownMenuItem(
                    value: 'page_count',
                    child: Text('Quantidade de páginas'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _metadataKey = value ?? 'source_item_id'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _metadataValue,
                maxLength: 120,
                maxLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Valor estruturado (opcional)',
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
        onPressed: () {
          if (!(_formKey.currentState?.validate() ?? false)) return;
          Navigator.pop(
            context,
            _ImportDraft(
              sourceType: _sourceType,
              sourceDigest: _sourceDigest.text.trim(),
              itemDigest: _itemDigest.text.trim(),
              evidenceType: _evidenceType,
              occurredAt: DateTime.now(),
              userId: _blankToNull(_userId.text),
              sessionId: _blankToNull(_sessionId.text),
              metadata: _metadataValue.text.trim().isEmpty
                  ? const {}
                  : {_metadataKey: _metadataValue.text.trim()},
            ),
          );
        },
        child: const Text('Enviar para revisão'),
      ),
    ],
  );

  Widget _digestField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        maxLength: 128,
        autocorrect: false,
        decoration: InputDecoration(labelText: label),
        validator: (value) =>
            RegExp(r'^[0-9a-f]{64,128}$').hasMatch(value?.trim() ?? '')
            ? null
            : 'Informe 64 a 128 caracteres hexadecimais minúsculos.',
      );
}

class _ImportDraft {
  const _ImportDraft({
    required this.sourceType,
    required this.sourceDigest,
    required this.itemDigest,
    required this.evidenceType,
    required this.occurredAt,
    required this.metadata,
    this.userId,
    this.sessionId,
  });

  final String sourceType;
  final String sourceDigest;
  final String itemDigest;
  final String evidenceType;
  final DateTime occurredAt;
  final String? userId;
  final String? sessionId;
  final Map<String, String> metadata;
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onRefresh});
  final EvidenceReport report;
  final VoidCallback onRefresh;

  Widget _presenceSummary() {
    final presence = report.summary['presence'];
    if (presence is! Map || presence['counts'] is! Map) {
      return const SizedBox.shrink();
    }
    final counts = presence['counts'] as Map;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Presenças confirmadas: ${counts['confirmed_present'] ?? 0}'),
        Text('Ausências justificadas: ${counts['justified_absence'] ?? 0}'),
        Text('Ausências registradas: ${counts['absent'] ?? 0}'),
        Text('Presenças ainda sem decisão: ${presence['pending_count'] ?? 0}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Card.filled(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Relatório auditável',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Gerado em ${_dateTime(report.generatedAt)}'),
          Text('Check-ins: ${report.summary['checkin_count'] ?? 0}'),
          Text(
            'Evidências ainda pendentes: ${(report.summary['pending_evidence_ids'] as List<dynamic>? ?? const []).length}',
          ),
          _presenceSummary(),
          const SizedBox(height: 8),
          SelectableText(
            'Digest: ${report.reportDigest}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Verificar relatório na API'),
          ),
        ],
      ),
    ),
  );
}

String? _blankToNull(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String _reasonLabel(String reason) => switch (reason) {
  'verified' => 'Verificada manualmente',
  'corrected' => 'Corrigida e verificada',
  'unrelated' => 'Não relacionada',
  'insufficient' => 'Informação insuficiente',
  'duplicate' => 'Duplicada',
  _ => reason,
};

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  return '${_date(local)} às ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
