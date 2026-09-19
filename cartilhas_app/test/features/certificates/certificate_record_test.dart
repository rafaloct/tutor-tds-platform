import 'package:cartilhas_app/features/certificates/models/certificate_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calcula o mesmo hash canônico do emissor JavaScript', () {
    final certificate = CertificateRecord(
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
      hash: '2e253e619b819d0c5dcc69d249972c3169eb00b88427d56da7136c756bceeb42',
      signature: 'a' * 64,
    );

    expect(certificate.hasValidLocalHash, isTrue);
    expect(
      certificate.computedHash,
      '2e253e619b819d0c5dcc69d249972c3169eb00b88427d56da7136c756bceeb42',
    );
  });

  test('detecta alteração local dos dados', () {
    final certificate = CertificateRecord.fromJson({
      'schemaVersion': 1,
      'id': 'TDS-2026-ABCDEF123456',
      'issuer': 'Tutor TDS - Programa TDS',
      'holderName': 'Nome adulterado',
      'courseId': 'cooperativismo',
      'courseTitle': 'Cooperativismo e Crédito',
      'issuedAt': '2026-08-11T12:34:56.000Z',
      'answeredQuestions': 4,
      'totalQuestions': 4,
      'verificationUrl': 'https://gateway.example/verify/TDS-2026-ABCDEF123456',
      'hash':
          '2e253e619b819d0c5dcc69d249972c3169eb00b88427d56da7136c756bceeb42',
      'signature': 'b' * 64,
    });

    expect(certificate.hasValidLocalHash, isFalse);
  });
}
