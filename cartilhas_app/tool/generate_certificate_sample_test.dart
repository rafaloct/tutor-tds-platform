import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/certificates/data/certificate_pdf_service.dart';
import 'package:cartilhas_app/features/certificates/data/certificate_repository.dart';
import 'package:cartilhas_app/features/certificates/models/certificate_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gera amostra visual do certificado', () async {
    final unsigned = CertificateRecord(
      schemaVersion: 1,
      id: 'TDS-2026-ABCDEF123456',
      issuer: 'Tutor TDS - Programa TDS',
      holderName: 'Maria de Oliveira da Silva',
      courseId: 'cooperativismo',
      courseTitle: 'Cooperativismo e Crédito',
      issuedAt: DateTime.parse('2026-08-11T12:34:56.000Z'),
      answeredQuestions: 4,
      totalQuestions: 4,
      verificationUrl: Uri.parse(
        'https://tutor-tds-gateway.tdsipex.workers.dev/verify/TDS-2026-ABCDEF123456',
      ),
      hash: '',
      signature: 'a' * 64,
    );
    final record = CertificateRecord(
      schemaVersion: unsigned.schemaVersion,
      id: unsigned.id,
      issuer: unsigned.issuer,
      holderName: unsigned.holderName,
      courseId: unsigned.courseId,
      courseTitle: unsigned.courseTitle,
      issuedAt: unsigned.issuedAt,
      answeredQuestions: unsigned.answeredQuestions,
      totalQuestions: unsigned.totalQuestions,
      verificationUrl: unsigned.verificationUrl,
      hash: unsigned.computedHash,
      signature: unsigned.signature,
      filePath:
          '/data/user/0/com.tutortds_cartilhas.dev/app_flutter/certificates/certificate-sample.pdf',
    );
    final secondUnsigned = CertificateRecord(
      schemaVersion: 1,
      id: 'TDS-2026-123456ABCDEF',
      issuer: 'Tutor TDS - Programa TDS',
      holderName: 'Maria de Oliveira da Silva',
      courseId: 'saf',
      courseTitle: 'Sistemas Agroflorestais (SAF)',
      issuedAt: DateTime.parse('2026-08-12T12:34:56.000Z'),
      answeredQuestions: 3,
      totalQuestions: 3,
      verificationUrl: Uri.parse(
        'https://tutor-tds-gateway.tdsipex.workers.dev/verify/TDS-2026-123456ABCDEF',
      ),
      hash: '',
      signature: 'b' * 64,
    );
    final second = CertificateRecord(
      schemaVersion: secondUnsigned.schemaVersion,
      id: secondUnsigned.id,
      issuer: secondUnsigned.issuer,
      holderName: secondUnsigned.holderName,
      courseId: secondUnsigned.courseId,
      courseTitle: secondUnsigned.courseTitle,
      issuedAt: secondUnsigned.issuedAt,
      answeredQuestions: secondUnsigned.answeredQuestions,
      totalQuestions: secondUnsigned.totalQuestions,
      verificationUrl: secondUnsigned.verificationUrl,
      hash: secondUnsigned.computedHash,
      signature: secondUnsigned.signature,
      filePath:
          '/data/user/0/com.tutortds_cartilhas.dev/app_flutter/certificates/certificate-saf-sample.pdf',
    );
    final service = CertificatePdfService(repository: CertificateRepository());
    final bytes = await service.build([record]);
    final output = File('build/certificate_sample.pdf');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes, flush: true);
    final fixture = Directory('build/certificate_fixture');
    await fixture.create(recursive: true);
    await File(
      '${fixture.path}/certificate-sample.pdf',
    ).writeAsBytes(bytes, flush: true);
    await File(
      '${fixture.path}/certificate-saf-sample.pdf',
    ).writeAsBytes(await service.build([second]), flush: true);
    await File(
      'build/certificate_portfolio_sample.pdf',
    ).writeAsBytes(await service.build([record, second]), flush: true);
    await File('${fixture.path}/index.json').writeAsString(
      jsonEncode([record.toJson(), second.toJson()]),
      flush: true,
    );

    expect(bytes.length, greaterThan(20000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
