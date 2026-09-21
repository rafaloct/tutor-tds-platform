import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/certificate_record.dart';
import 'certificate_pdf_service.dart';
import 'certificate_repository.dart';

class CertificateService {
  final String gatewayUrl;
  final CertificateRepository repository;
  final CertificatePdfService pdfService;
  final http.Client _client;
  final bool _ownsClient;

  factory CertificateService({
    required String gatewayUrl,
    CertificateRepository? repository,
    CertificatePdfService? pdfService,
    http.Client? client,
  }) {
    final resolvedRepository = repository ?? CertificateRepository();
    return CertificateService._(
      gatewayUrl: gatewayUrl,
      repository: resolvedRepository,
      pdfService:
          pdfService ?? CertificatePdfService(repository: resolvedRepository),
      client: client ?? http.Client(),
      ownsClient: client == null,
    );
  }

  CertificateService._({
    required this.gatewayUrl,
    required this.repository,
    required this.pdfService,
    required http.Client client,
    required bool ownsClient,
  }) : _client = client,
       _ownsClient = ownsClient;

  Future<List<CertificateRecord>> loadAll() => repository.loadAll();

  Future<CertificateRecord?> findByCourse(String courseId) =>
      repository.findByCourse(courseId);

  Future<CertificateRecord> issue({
    required String holderName,
    required String cpf,
    required String courseId,
    required int answeredQuestions,
    required int totalQuestions,
  }) async {
    final base = Uri.tryParse(gatewayUrl);
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      throw const CertificateException(
        'Serviço de certificados não configurado.',
      );
    }
    if (!isValidCpf(cpf)) {
      throw const CertificateException('Informe um CPF válido no cadastro.');
    }

    late final http.Response response;
    try {
      response = await _client
          .post(
            base.resolve('/v1/certificates'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'holderName': holderName.trim(),
              'cpf': cpf.replaceAll(RegExp(r'\D'), ''),
              'courseId': courseId,
              'answeredQuestions': answeredQuestions,
              'totalQuestions': totalQuestions,
            }),
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const CertificateException(
        'A emissão demorou demais. Tente novamente.',
      );
    } on Object {
      throw const CertificateException('Não foi possível conectar ao emissor.');
    }

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      throw const CertificateException(
        'O emissor retornou uma resposta inválida.',
      );
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CertificateException(_messageForError(payload['error'] as String?));
    }

    final rawCertificate = payload['certificate'];
    if (rawCertificate is! Map) {
      throw const CertificateException(
        'Certificado ausente na resposta do emissor.',
      );
    }
    final certificate = CertificateRecord.fromJson(
      Map<String, dynamic>.from(rawCertificate),
    );
    if (!certificate.hasValidLocalHash) {
      throw const CertificateException('O hash do certificado não confere.');
    }

    final filePath = await pdfService.save(certificate);
    final stored = certificate.copyWith(filePath: filePath);
    await repository.upsert(stored);
    return stored;
  }

  Future<bool> verifyOnline(CertificateRecord certificate) async {
    final base = Uri.tryParse(gatewayUrl);
    if (base == null) return false;
    try {
      final response = await _client
          .get(base.resolve('/v1/certificates/${certificate.id}'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return false;
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return payload['valid'] == true;
    } on Object {
      return false;
    }
  }

  Future<void> printCertificates(List<CertificateRecord> records) async {
    final bytes = await pdfService.build(records);
    await Printing.layoutPdf(
      name: records.length == 1
          ? 'certificado-tds.pdf'
          : 'certificados-tds.pdf',
      format: PdfPageFormat.a4.landscape,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  Future<void> shareCertificates(
    List<CertificateRecord> records, {
    bool email = false,
  }) async {
    if (records.isEmpty) throw ArgumentError('Nenhum certificado selecionado.');
    final files = <XFile>[];
    for (final record in records) {
      var path = record.filePath;
      if (path == null || !await File(path).exists()) {
        path = await pdfService.save(record);
        await repository.upsert(record.copyWith(filePath: path));
      }
      files.add(XFile(path, mimeType: 'application/pdf'));
    }

    await SharePlus.instance.share(
      ShareParams(
        title: 'Certificados Tutor TDS',
        subject: email ? 'Meus certificados Tutor TDS' : null,
        text: email
            ? 'Olá! Seguem meus certificados verificáveis emitidos pelo Tutor TDS.'
            : 'Certificados verificáveis emitidos pelo Tutor TDS.',
        files: files,
      ),
    );
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }

  static bool isValidCpf(String value) {
    final cpf = value.replaceAll(RegExp(r'\D'), '');
    if (cpf.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;
    for (var digit = 9; digit < 11; digit++) {
      var sum = 0;
      for (var index = 0; index < digit; index++) {
        sum += int.parse(cpf[index]) * (digit + 1 - index);
      }
      final check = ((sum * 10) % 11) % 10;
      if (check != int.parse(cpf[digit])) return false;
    }
    return true;
  }

  String _messageForError(String? error) => switch (error) {
    'cpf_invalid' => 'Informe um CPF válido no cadastro.',
    'holder_name_invalid' => 'Informe seu nome completo no cadastro.',
    'course_not_completed' => 'Conclua todas as perguntas antes de emitir.',
    'course_invalid' => 'Esta cartilha não está habilitada para certificação.',
    'certificate_service_not_configured' =>
      'O serviço de certificados está temporariamente indisponível.',
    _ => 'Não foi possível emitir o certificado agora.',
  };
}

class CertificateException implements Exception {
  final String message;
  const CertificateException(this.message);

  @override
  String toString() => message;
}
