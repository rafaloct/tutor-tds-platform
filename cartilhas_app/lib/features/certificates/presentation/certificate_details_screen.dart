import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/certificate_service.dart';
import '../models/certificate_record.dart';
import '../../../widgets/tds_brand_stripe.dart';

class CertificateDetailsScreen extends StatefulWidget {
  final CertificateRecord certificate;

  const CertificateDetailsScreen({super.key, required this.certificate});

  @override
  State<CertificateDetailsScreen> createState() =>
      _CertificateDetailsScreenState();
}

class _CertificateDetailsScreenState extends State<CertificateDetailsScreen> {
  bool? _onlineValid;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    final valid = await context.read<CertificateService>().verifyOnline(
      widget.certificate,
    );
    if (mounted) setState(() => _onlineValid = valid);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
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
    final certificate = widget.certificate;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Certificado')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        const TdsBrandStripe(height: 5),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/branding/logo_tds_fundo_branco.png',
                                width: 150,
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'CERTIFICADO',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                certificate.holderName,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                certificate.courseTitle,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFDCE2F2),
                                  ),
                                ),
                                child: QrImageView(
                                  data: certificate.verificationUrl.toString(),
                                  version: QrVersions.auto,
                                  size: 166,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Color(0xFF262626),
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Color(0xFF262626),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ValidationChip(valid: _onlineValid),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(
                            label: 'Identificador',
                            value: certificate.id,
                          ),
                          _InfoRow(
                            label: 'Emissão',
                            value: _formatDate(certificate.issuedAt),
                          ),
                          _InfoRow(
                            label: 'Progresso',
                            value:
                                '${certificate.answeredQuestions}/${certificate.totalQuestions} perguntas',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hash SHA-256',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 5),
                          SelectableText(
                            certificate.hash,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => context
                                    .read<CertificateService>()
                                    .shareCertificates([certificate]),
                              ),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Compartilhar PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => context
                                    .read<CertificateService>()
                                    .printCertificates([certificate]),
                              ),
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Imprimir'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => context
                                    .read<CertificateService>()
                                    .shareCertificates([
                                      certificate,
                                    ], email: true),
                              ),
                        icon: const Icon(Icons.email_outlined),
                        label: const Text('Enviar por e-mail'),
                      ),
                      TextButton.icon(
                        onPressed: () => launchUrl(
                          certificate.verificationUrl,
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Abrir validação'),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationChip extends StatelessWidget {
  final bool? valid;
  const _ValidationChip({required this.valid});

  @override
  Widget build(BuildContext context) {
    if (valid == null) {
      return const Chip(
        avatar: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text('Validando no servidor'),
      );
    }
    if (valid == true) {
      return const Chip(
        avatar: Icon(Icons.verified, size: 18, color: Color(0xFF087C03)),
        label: Text('Registro verificado'),
      );
    }
    return const Chip(
      avatar: Icon(Icons.cloud_off_outlined, size: 18),
      label: Text('Não foi possível validar agora'),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
