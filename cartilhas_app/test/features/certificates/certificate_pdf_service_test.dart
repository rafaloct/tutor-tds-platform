import 'dart:io';

import 'package:cartilhas_app/features/certificates/data/certificate_pdf_service.dart';
import 'package:cartilhas_app/features/certificates/data/certificate_repository.dart';
import 'package:cartilhas_app/features/certificates/models/certificate_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late CertificatePdfService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'tutor-tds-certificate-pdf-test-',
    );
    service = CertificatePdfService(
      repository: CertificateRepository(
        documentsDirectoryProvider: () async => temporaryDirectory,
      ),
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('recusa geração sem certificados', () async {
    await expectLater(service.build(const []), throwsArgumentError);
  });

  test(
    'gera PDF verificável de uma ou várias páginas e salva nome seguro',
    () async {
      final first = _certificate(
        id: 'TDS-2026-ABCDEF123456',
        courseId: 'curso com/espaços',
        courseTitle: 'Cooperativismo e Crédito',
        issuedAt: DateTime.utc(2026, 8, 11, 12, 34, 56),
      );
      final second = _certificate(
        id: 'TDS-2026-123456ABCDEF',
        courseId: 'saf',
        courseTitle: 'Sistemas Agroflorestais',
        issuedAt: DateTime.utc(2026, 9, 20),
      );

      final onePage = await service.build([first]);
      final twoPages = await service.build([first, second]);
      final path = await service.save(first);

      expect(String.fromCharCodes(onePage.take(5)), '%PDF-');
      expect(String.fromCharCodes(twoPages.take(5)), '%PDF-');
      expect(twoPages.length, greaterThan(onePage.length));
      expect(
        path,
        endsWith(
          '${Platform.pathSeparator}certificado-tds-curso-com-espa-os-tds-2026-abcdef123456.pdf',
        ),
      );
      final saved = File(path);
      expect(await saved.exists(), isTrue);
      expect(await saved.length(), greaterThan(1000));
    },
  );
}

CertificateRecord _certificate({
  required String id,
  required String courseId,
  required String courseTitle,
  required DateTime issuedAt,
}) {
  final unsigned = CertificateRecord(
    schemaVersion: 1,
    id: id,
    issuer: 'Tutor TDS - Programa TDS',
    holderName: 'Maria da Silva',
    courseId: courseId,
    courseTitle: courseTitle,
    issuedAt: issuedAt,
    answeredQuestions: 4,
    totalQuestions: 4,
    verificationUrl: Uri.parse('https://gateway.example/verify/$id'),
    hash: '',
    signature: 'a' * 64,
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
  );
}
