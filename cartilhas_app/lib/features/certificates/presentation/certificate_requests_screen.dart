import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/app_config.dart';
import '../../analytics/telemetry_route.dart';
import '../../analytics/app_telemetry_service.dart';
import '../../auth/data/auth_repository.dart';
import '../data/certificate_request_repository.dart';
import '../models/certificate_request.dart';

/// Requests and human decisions are online operations, never offline approvals.
class CertificateRequestsScreen extends StatefulWidget {
  const CertificateRequestsScreen({
    super.key,
    this.gateway,
    this.courseId,
    this.courseVersionId,
    this.classId,
    this.reviewMode = false,
  });
  final CertificateRequestGateway? gateway;
  final String? courseId;
  final String? courseVersionId;
  final String? classId;
  final bool reviewMode;

  @override
  State<CertificateRequestsScreen> createState() =>
      _CertificateRequestsScreenState();
}

class _CertificateRequestsScreenState extends State<CertificateRequestsScreen> {
  late final CertificateRequestGateway _gateway;
  List<CertificateRequest> _requests = const [];
  List<CertificateRequestContext> _contexts = const [];
  CertificateRequestContext? _selected;
  bool _loading = true;
  bool _busy = false;
  bool _canReview = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gateway =
        widget.gateway ??
        CertificateRequestRepository(
          apiUrl: AppConfig.tutorApiUrl,
          authRepository: context.read<AuthRepository>(),
        );
    _load();
  }

  @override
  void dispose() {
    if (widget.gateway == null && _gateway is CertificateRequestRepository) {
      _gateway.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _requests = const [];
      _contexts = const [];
      _selected = null;
      _canReview = false;
    });
    try {
      final rows = widget.reviewMode
          ? await _gateway.reviewQueue()
          : await _gateway.ownRequests();
      final contexts =
          !widget.reviewMode &&
              widget.courseId != null &&
              widget.courseVersionId != null
          ? await _gateway.contexts(widget.courseId!, widget.courseVersionId!)
          : <CertificateRequestContext>[];
      var canReview = widget.reviewMode;
      if (!widget.reviewMode) {
        try {
          await _gateway.reviewQueue();
          canReview = true;
        } on CertificateRequestException catch (error) {
          // Only lack of review authority is optional. Session/network errors
          // must not publish rows obtained before an account change.
          if (error.statusCode != 403) rethrow;
        }
      }
      if (!mounted) return;
      setState(() {
        _requests = rows
            .where(
              (row) =>
                  widget.courseId == null ||
                  row.courseId == widget.courseId &&
                      (widget.courseVersionId == null ||
                          row.courseVersionId == widget.courseVersionId),
            )
            .toList();
        _contexts = contexts
            .where(
              (row) =>
                  (widget.classId == null || row.classId == widget.classId) &&
                  !rows.any(
                    (existing) =>
                        existing.enrollmentId == row.enrollmentId &&
                        existing.courseVersionId == row.courseVersionId,
                  ),
            )
            .toList();
        _selected = _contexts.length == 1 ? _contexts.single : null;
        _canReview = canReview;
      });
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(Object error) => error is CertificateRequestException
      ? error.message
      : 'Não foi possível consultar os pedidos. Confira sua conexão e tente novamente.';

  void _showError(Object error) => setState(() {
    _error = _message(error);
    if (error is CertificateRequestException && error.statusCode == 401) {
      _requests = const [];
      _contexts = const [];
      _selected = null;
      _canReview = false;
    }
  });

  Future<void> _run(Future<void> Function() action, String featureId) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        // Analytics never includes names, reasons or academic evidence.
        try {
          await Provider.of<AppTelemetryService?>(
            context,
            listen: false,
          )?.trackFeature(featureId: featureId);
        } on Object {
          /* Domain result does not depend on optional telemetry. */
        }
        if (mounted) await _load();
      }
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _create() async {
    final selected = _selected;
    if (selected == null || _busy) return;
    if (!await _confirm(
      'Solicitar análise do certificado?',
      'A equipe verá seu nome, matrícula, edição do curso e evidências de aprendizagem. '
          'Este pedido não emite nem publica um certificado. A emissão depende de análise humana e dos critérios validados.',
    )) {
      return;
    }
    if (!mounted) return;
    await _run(() async {
      await _gateway.create(selected);
    }, 'certificate_request_created');
  }

  Future<void> _review(CertificateRequest row, String decision) async {
    if (_busy) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ReviewDialog(approve: decision == 'approve', holder: row.holderName),
    );
    if (reason == null || !mounted) return;
    await _run(() async {
      await _gateway.review(row.id, decision, row.revision, reason);
    }, 'certificate_review_recorded');
  }

  Future<void> _resubmit(CertificateRequest row) async {
    if (_busy ||
        !await _confirm(
          'Pedir nova análise?',
          'Confirme após atender às orientações da equipe. O histórico anterior será preservado.',
        )) {
      return;
    }
    if (!mounted) return;
    await _run(() async {
      await _gateway.resubmit(row.id, row.revision);
    }, 'certificate_request_resubmitted');
  }

  String _status(CertificateRequest row) => switch (row.status) {
    'pending' => 'Aguardando análise da equipe',
    'approved' => 'Aprovado — emissão pendente',
    'rejected' => 'Precisa de ajustes',
    _ => 'Atualize para conferir o pedido',
  };

  Widget _evidence(CertificateRequestEligibility evidence) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Tempo validado: ${(evidence.validatedSeconds / 3600).toStringAsFixed(2)} h de ${(evidence.requiredSeconds / 3600).toStringAsFixed(2)} h',
      ),
      Text(
        evidence.completed
            ? 'Conclusão registrada nesta edição'
            : 'Conclusão desta edição ainda não registrada',
      ),
      Text(
        evidence.eligible
            ? 'Critérios disponíveis para revisão humana'
            : 'Há critérios pendentes. Confira a sincronização e procure sua equipe.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.reviewMode ? 'Revisar certificados' : 'Pedidos de certificado',
      ),
      actions: [
        if (_canReview && !widget.reviewMode)
          IconButton(
            tooltip: 'Revisar pedidos',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: _busy
                ? null
                : () => Navigator.push(
                    context,
                    trackedRoute(
                      pageId: 'certificate_review',
                      featureId: 'certificate_review',
                      builder: (_) => CertificateRequestsScreen(
                        gateway: widget.gateway,
                        reviewMode: true,
                      ),
                    ),
                  ),
          ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.reviewMode
                    ? 'Revise as evidências antes de decidir. A aprovação é pessoal, fica registrada e não equivale à emissão do documento.'
                    : 'Seu certificado acompanha a matrícula e a edição cursada. A equipe analisa a conclusão e a carga horária; não há emissão automática.',
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('certificate-request-error'),
                  semanticsLabel: 'Atenção: $_error',
                ),
              TextButton.icon(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar pedidos'),
              ),
              if (!widget.reviewMode &&
                  widget.courseId != null &&
                  (_requests.isEmpty || _contexts.isNotEmpty)) ...[
                if (_contexts.isEmpty)
                  const Text(
                    'Nenhuma matrícula disponível para esta edição. Atualize o curso com internet ou peça ajuda à equipe para conferir seu vínculo.',
                  ),
                if (_contexts.isNotEmpty) ...[
                  DropdownButtonFormField<CertificateRequestContext>(
                    key: ValueKey(_contexts),
                    initialValue: _selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Matrícula para o pedido',
                    ),
                    items: _contexts
                        .map(
                          (row) => DropdownMenuItem(
                            value: row,
                            child: Text(
                              '${row.programName} • ${row.className ?? 'Estudo individual'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _selected = value),
                  ),
                  if (_selected != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _evidence(_selected!.eligibility),
                    ),
                  FilledButton.icon(
                    onPressed: _busy || _selected == null ? null : _create,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Solicitar análise'),
                  ),
                ],
              ],
              if (_requests.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    widget.reviewMode
                        ? 'Nenhum pedido disponível para revisão no seu escopo.'
                        : 'Você ainda não tem pedidos nesta consulta.',
                  ),
                ),
              for (final row in _requests)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.courseTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (widget.reviewMode) Text(row.holderName),
                        Text(row.programName),
                        Text(
                          row.className ??
                              (row.classId == null
                                  ? 'Estudo individual'
                                  : 'Turma: ${row.classId}'),
                        ),
                        if (widget.classId != null &&
                            row.classId != widget.classId)
                          const Text(
                            'Este pedido da mesma matrícula e edição foi aberto em outro contexto. Não é necessário criar outro pedido.',
                          ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Identificação do pedido'),
                          children: [
                            SelectableText(
                              'Matrícula: ${row.enrollmentId}\nEdição: ${row.courseVersionId}\nPedido: ${row.id}',
                            ),
                          ],
                        ),
                        Text(
                          _status(row),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        _evidence(row.eligibility),
                        if (row.reviewReason != null)
                          Text('Orientação da equipe: ${row.reviewReason}'),
                        if (widget.reviewMode && row.status == 'pending')
                          Wrap(
                            spacing: 12,
                            children: [
                              FilledButton(
                                onPressed: _busy || !row.eligibility.eligible
                                    ? null
                                    : () => _review(row, 'approve'),
                                child: const Text('Aprovar análise'),
                              ),
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _review(row, 'reject'),
                                child: const Text('Pedir ajustes'),
                              ),
                            ],
                          ),
                        if (!widget.reviewMode && row.status == 'rejected')
                          TextButton(
                            onPressed: _busy ? null : () => _resubmit(row),
                            child: const Text('Solicitar nova análise'),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_busy) const Center(child: CircularProgressIndicator()),
            ],
          ),
  );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.approve, required this.holder});
  final bool approve;
  final String holder;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.approve ? 'Confirmar aprovação humana' : 'Orientar ajustes',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pedido de ${widget.holder}. Registre apenas a justificativa pedagógica, sem CPF, telefone ou dados sensíveis.',
            ),
            TextFormField(
              controller: _reason,
              maxLength: 500,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Justificativa para o estudante',
              ),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Escreva a justificativa.'
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
            Navigator.pop(context, _reason.text.trim());
          }
        },
        child: const Text('Registrar decisão'),
      ),
    ],
  );
}
