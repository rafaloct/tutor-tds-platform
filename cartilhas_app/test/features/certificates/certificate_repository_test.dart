import 'dart:io';

import 'package:cartilhas_app/features/certificates/data/certificate_repository.dart';
import 'package:cartilhas_app/features/certificates/models/certificate_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late CertificateRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'tutor-tds-certificates-test-',
    );
    repository = CertificateRepository(
      documentsDirectoryProvider: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('acumula certificados e substitui duplicata pelo id', () async {
    final first = _certificate(
      id: 'TDS-2026-ABCDEF123456',
      courseId: 'cooperativismo',
      courseTitle: 'Cooperativismo e Crédito',
      filePath: 'primeiro.pdf',
    );
    final second = _certificate(
      id: 'TDS-2026-123456ABCDEF',
      courseId: 'saf',
      courseTitle: 'Sistemas Agroflorestais (SAF)',
      filePath: 'segundo.pdf',
    );

    await repository.upsert(first);
    await repository.upsert(second);
    await repository.upsert(first.copyWith(filePath: 'atualizado.pdf'));

    final stored = await repository.loadAll();
    expect(stored, hasLength(2));
    expect(
      stored.singleWhere((item) => item.id == first.id).filePath,
      'atualizado.pdf',
    );
    expect((await repository.findByCourse('saf'))?.id, second.id);
  });
}

CertificateRecord _certificate({
  required String id,
  required String courseId,
  required String courseTitle,
  required String filePath,
}) {
  final unsigned = CertificateRecord(
    schemaVersion: 1,
    id: id,
    issuer: 'Tutor TDS - Programa TDS',
    holderName: 'Maria da Silva',
    courseId: courseId,
    courseTitle: courseTitle,
    issuedAt: DateTime.parse('2026-08-11T12:34:56.000Z'),
    answeredQuestions: 4,
    totalQuestions: 4,
    verificationUrl: Uri.parse('https://gateway.example/verify/$id'),
    hash: '',
    signature: 'c' * 64,
    filePath: filePath,
  );
  return CertificateRecord(
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
    filePath: unsigned.filePath,
  );
}
