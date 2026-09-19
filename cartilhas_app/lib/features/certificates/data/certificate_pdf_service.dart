import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/certificate_record.dart';
import 'certificate_repository.dart';

class CertificatePdfService {
  final CertificateRepository repository;
  Future<_CertificatePdfAssets>? _assets;

  CertificatePdfService({required this.repository});

  Future<Uint8List> build(List<CertificateRecord> records) async {
    if (records.isEmpty) {
      throw ArgumentError('Selecione ao menos um certificado.');
    }
    final assets = await (_assets ??= _loadAssets());
    final document = pw.Document(
      title: records.length == 1
          ? 'Certificado ${records.first.courseTitle}'
          : 'Certificados Tutor TDS',
      author: 'Tutor TDS',
      creator: 'Tutor TDS',
      subject: 'Certificados verificáveis de conclusão',
    );

    for (final record in records) {
      document.addPage(_certificatePage(record, assets));
    }
    return document.save();
  }

  Future<String> save(CertificateRecord record) async {
    final directory = await repository.certificatesDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}${_safeFileName(record)}.pdf',
    );
    await file.writeAsBytes(await build([record]), flush: true);
    return file.path;
  }

  pw.Page _certificatePage(
    CertificateRecord record,
    _CertificatePdfAssets assets,
  ) {
    const blue = PdfColor.fromInt(0xFF093AF4);
    const red = PdfColor.fromInt(0xFFFF341B);
    const yellow = PdfColor.fromInt(0xFFF6D846);
    const green = PdfColor.fromInt(0xFF18D010);
    const ink = PdfColor.fromInt(0xFF262626);
    const muted = PdfColor.fromInt(0xFF6B6B6B);
    const soft = PdfColor.fromInt(0xFFF5F7FC);

    final baseStyle = pw.TextStyle(font: assets.regular, color: ink);
    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      theme: pw.ThemeData.withFont(base: assets.regular, bold: assets.bold),
      build: (_) => pw.Container(
        color: PdfColors.white,
        padding: const pw.EdgeInsets.all(15 * PdfPageFormat.mm),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: blue, width: 1.8),
          ),
          padding: const pw.EdgeInsets.all(14 * PdfPageFormat.mm),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(assets.logo, width: 116),
                  pw.Spacer(),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: pw.BoxDecoration(
                      color: soft,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text(
                      'VERIFICÁVEL POR QR CODE',
                      style: pw.TextStyle(
                        font: assets.bold,
                        fontSize: 8,
                        color: blue,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'CERTIFICADO',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: assets.extraBold,
                  color: blue,
                  fontSize: 30,
                  letterSpacing: 2.2,
                ),
              ),
              pw.SizedBox(height: 9),
              pw.Text(
                'O ${record.issuer} certifica que',
                textAlign: pw.TextAlign.center,
                style: baseStyle.copyWith(fontSize: 11, color: muted),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                record.holderName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: assets.bold,
                  color: ink,
                  fontSize: 23,
                ),
                maxLines: 2,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'concluiu integralmente a cartilha',
                textAlign: pw.TextAlign.center,
                style: baseStyle.copyWith(fontSize: 11, color: muted),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                record.courseTitle,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: assets.bold,
                  color: ink,
                  fontSize: 17,
                ),
                maxLines: 2,
              ),
              pw.Spacer(),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Emitido em ${_formatDate(record.issuedAt)}',
                          style: baseStyle.copyWith(fontSize: 9.5),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'ID ${record.id}',
                          style: pw.TextStyle(
                            font: assets.bold,
                            color: ink,
                            fontSize: 9.5,
                          ),
                        ),
                        pw.SizedBox(height: 9),
                        pw.Container(width: 154, height: 1, color: ink),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Tutor TDS - emissão automatizada',
                          style: baseStyle.copyWith(fontSize: 8, color: muted),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFFDCE2F2),
                      ),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: record.verificationUrl.toString(),
                      width: 70,
                      height: 70,
                      color: ink,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                    width: 148,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VALIDAR AUTENTICIDADE',
                          style: pw.TextStyle(
                            font: assets.bold,
                            color: blue,
                            fontSize: 8.5,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Aponte a câmera para o QR Code. A página pública confirma os dados e a assinatura do registro.',
                          style: baseStyle.copyWith(
                            fontSize: 7.5,
                            color: muted,
                            lineSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 9),
              pw.Text(
                'SHA-256 ${record.hash}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: assets.regular,
                  color: muted,
                  fontSize: 6.5,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Container(height: 4, color: blue)),
                  pw.Expanded(child: pw.Container(height: 4, color: red)),
                  pw.Expanded(child: pw.Container(height: 4, color: yellow)),
                  pw.Expanded(child: pw.Container(height: 4, color: green)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_CertificatePdfAssets> _loadAssets() async {
    final regular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
    final extraBold = await rootBundle.load(
      'assets/fonts/Poppins-ExtraBold.ttf',
    );
    final logo = await rootBundle.load(
      'assets/branding/logo_tds_fundo_branco.png',
    );
    return _CertificatePdfAssets(
      regular: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
      extraBold: pw.Font.ttf(extraBold),
      logo: pw.MemoryImage(logo.buffer.asUint8List()),
    );
  }

  String _safeFileName(CertificateRecord record) {
    final course = record.courseId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    return 'certificado-tds-$course-${record.id.toLowerCase()}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')} de ${months[local.month - 1]} de ${local.year}';
  }
}

class _CertificatePdfAssets {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font extraBold;
  final pw.MemoryImage logo;

  const _CertificatePdfAssets({
    required this.regular,
    required this.bold,
    required this.extraBold,
    required this.logo,
  });
}
