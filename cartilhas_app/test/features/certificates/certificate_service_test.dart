import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/certificates/data/certificate_pdf_service.dart';
import 'package:cartilhas_app/features/certificates/data/certificate_repository.dart';
import 'package:cartilhas_app/features/certificates/data/certificate_service.dart';
import 'package:cartilhas_app/features/certificates/models/certificate_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory temporaryDirectory;
  late CertificateRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'tutor-tds-service-test-',
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

  test('valida resposta, salva PDF e adiciona à carteira', () async {
    late Map<String, dynamic> sentBody;
    final certificate = _serverCertificate();
    final client = MockClient((request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'certificate': certificate.toJson(),
          'alreadyIssued': false,
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = CertificateService(
      gatewayUrl: 'https://gateway.example',
      repository: repository,
      pdfService: _FakePdfService(repository: repository),
      client: client,
    );

    final issued = await service.issue(
      holderName: 'Maria da Silva',
      cpf: '529.982.247-25',
      courseId: 'cooperativismo',
      answeredQuestions: 4,
      totalQuestions: 4,
    );

    expect(sentBody['cpf'], '52998224725');
    expect(sentBody.containsKey('phone'), isFalse);
    expect(issued.filePath, isNotNull);
    expect(await File(issued.filePath!).exists(), isTrue);
    expect(await repository.loadAll(), hasLength(1));
  });

  test('recusa hash adulterado antes de salvar', () async {
    final certificate = _serverCertificate().toJson();
    certificate['holderName'] = 'Nome adulterado';
    final service = CertificateService(
      gatewayUrl: 'https://gateway.example',
      repository: repository,
      pdfService: _FakePdfService(repository: repository),
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'certificate': certificate}), 201),
      ),
    );

    expect(
      () => service.issue(
        holderName: 'Maria da Silva',
        cpf: '52998224725',
        courseId: 'cooperativismo',
        answeredQuestions: 4,
        totalQuestions: 4,
      ),
      throwsA(isA<CertificateException>()),
    );
    expect(await repository.loadAll(), isEmpty);
  });

  test('valida CPF com dígitos verificadores', () {
    expect(CertificateService.isValidCpf('529.982.247-25'), isTrue);
    expect(CertificateService.isValidCpf('111.111.111-11'), isFalse);
    expect(CertificateService.isValidCpf('529.982.247-26'), isFalse);
  });
}

class _FakePdfService extends CertificatePdfService {
  _FakePdfService({required super.repository});

  @override
  Future<String> save(CertificateRecord record) async {
    final directory = await repository.certificatesDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}${record.id}.pdf',
    );
    await file.writeAsString('%PDF-1.4 test');
    return file.path;
  }
}

CertificateRecord _serverCertificate() {
  final unsigned = CertificateRecord(
    schemaVersion: 1,
    id: 'TDS-2026-ABCDEF123456',
    issuer: 'Tutor TDS - Programa TDS',
    holderName: 'Maria da Silva',
    courseId: 'cooperativismo',
    courseTitle: 'Cooperativismo e Crédito',
    issuedAt: DateTime.parse('2026-08-11T12:34:56.000Z'),
    answeredQuestions: 4,
    totalQuestions: 4,
    verificationUrl: Uri.parse(
      'https://gateway.example/verify/TDS-2026-ABCDEF123456',
    ),
    hash: '',
    signature: 'd' * 64,
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
