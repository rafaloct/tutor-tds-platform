import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/certificate_service.dart';
import '../models/certificate_record.dart';
import 'certificate_details_screen.dart';
import '../../analytics/telemetry_route.dart';

class CertificateWalletScreen extends StatefulWidget {
  const CertificateWalletScreen({super.key});

  @override
  State<CertificateWalletScreen> createState() =>
      _CertificateWalletScreenState();
}

class _CertificateWalletScreenState extends State<CertificateWalletScreen> {
  List<CertificateRecord> _certificates = const [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _selecting => _selected.isNotEmpty;
  List<CertificateRecord> get _selectedRecords =>
      _certificates.where((item) => _selected.contains(item.id)).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final certificates = await context.read<CertificateService>().loadAll();
      if (mounted) {
        setState(() {
          _certificates = certificates;
          _loading = false;
          _error = null;
          _selected.removeWhere(
            (id) => !certificates.any((item) => item.id == id),
          );
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível abrir a carteira neste momento.';
        });
      }
    }
  }

  void _toggle(CertificateRecord certificate) {
    setState(() {
      if (!_selected.add(certificate.id)) _selected.remove(certificate.id);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _selectedRecords.isEmpty) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível concluir: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selecting
              ? IconButton(
                  onPressed: () => setState(_selected.clear),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancelar seleção',
                )
              : null,
          title: Text(
            _selecting
                ? '${_selected.length} selecionado${_selected.length == 1 ? '' : 's'}'
                : 'Meus certificados',
          ),
          actions: [
            if (_certificates.isNotEmpty)
              IconButton(
                tooltip: _selected.length == _certificates.length
                    ? 'Limpar seleção'
                    : 'Selecionar todos',
                onPressed: () => setState(() {
                  if (_selected.length == _certificates.length) {
                    _selected.clear();
                  } else {
                    _selected.addAll(_certificates.map((item) => item.id));
                  }
                }),
                icon: Icon(
                  _selected.length == _certificates.length
                      ? Icons.deselect
                      : Icons.select_all,
                ),
              ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _selecting ? _buildActions() : null,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined, size: 52),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_certificates.isEmpty) return const _EmptyWallet();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        itemCount: _certificates.length,
        itemBuilder: (context, index) {
          final certificate = _certificates[index];
          final selected = _selected.contains(certificate.id);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onLongPress: () => _toggle(certificate),
                  onTap: () async {
                    if (_selecting) {
                      _toggle(certificate);
                      return;
                    }
                    await Navigator.push(
                      context,
                      trackedRoute(
                        pageId: 'certificate_details',
                        courseId: certificate.courseId,
                        resourceId: 'certificate',
                        featureId: 'certificate_view',
                        builder: (_) =>
                            CertificateDetailsScreen(certificate: certificate),
                      ),
                    );
                    await _load();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (_selecting) ...[
                          Checkbox(
                            value: selected,
                            onChanged: (_) => _toggle(certificate),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Container(
                          width: 48,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.workspace_premium_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                certificate.courseTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                certificate.holderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_outlined,
                                    color: Color(0xFF087C03),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Hash verificado • ${_formatDate(certificate.issuedAt)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!_selecting) const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActions() {
    final service = context.read<CertificateService>();
    return SafeArea(
      top: false,
      child: Material(
        elevation: 12,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionButton(
                icon: Icons.print_outlined,
                label: 'Imprimir',
                enabled: !_busy,
                onTap: () =>
                    _run(() => service.printCertificates(_selectedRecords)),
              ),
              _ActionButton(
                icon: Icons.ios_share_outlined,
                label: 'Exportar',
                enabled: !_busy,
                onTap: () =>
                    _run(() => service.shareCertificates(_selectedRecords)),
              ),
              _ActionButton(
                icon: Icons.email_outlined,
                label: 'E-mail',
                enabled: !_busy,
                onTap: () => _run(
                  () =>
                      service.shareCertificates(_selectedRecords, email: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _EmptyWallet extends StatelessWidget {
  const _EmptyWallet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sua carteira está vazia',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Conclua uma cartilha e responda todas as perguntas para emitir seu primeiro certificado verificável.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
