import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/certificate_record.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();

/// Persistencia local da carteira de certificados.
///
/// - Plataformas nativas: `<documents>/certificates/index.json` + PDFs em disco.
/// - Web: indice JSON em SharedPreferences (localStorage); `filePath` fica nulo
///   e os bytes do PDF sao reconstruidos sob demanda via pdfService.build().
class CertificateRepository {
  final DocumentsDirectoryProvider _documentsDirectoryProvider;

  static const _webIndexKey = 'certificate_index_v1';

  CertificateRepository({
    DocumentsDirectoryProvider? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  Future<Directory> certificatesDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Sistema de arquivos indisponivel no web; use o indice SharedPreferences.',
      );
    }
    final documents = await _documentsDirectoryProvider();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}certificates',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<List<CertificateRecord>> loadAll() async {
    final decoded = kIsWeb ? await _readIndexWeb() : await _readIndexFile();
    if (decoded == null) return [];
    if (decoded is! List) {
      throw const FormatException('Índice de certificados inválido.');
    }
    final records =
        decoded
            .whereType<Map>()
            .map(
              (item) =>
                  CertificateRecord.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((record) => record.hasValidLocalHash)
            .toList()
          ..sort((left, right) => right.issuedAt.compareTo(left.issuedAt));
    return records;
  }

  Future<dynamic> _readIndexFile() async {
    final directory = await certificatesDirectory();
    final index = File('${directory.path}${Platform.pathSeparator}index.json');
    if (!await index.exists()) return null;
    return jsonDecode(await index.readAsString());
  }

  Future<dynamic> _readIndexWeb() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_webIndexKey);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  Future<void> upsert(CertificateRecord record) async {
    if (!record.hasValidLocalHash) {
      throw const FormatException('Hash local do certificado inválido.');
    }
    final records = await loadAll();
    final index = records.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      records[index] = record;
    } else {
      records.add(record);
    }
    records.sort((left, right) => right.issuedAt.compareTo(left.issuedAt));
    await _writeIndex(records);
  }

  Future<CertificateRecord?> findByCourse(String courseId) async {
    final records = await loadAll();
    for (final record in records) {
      if (record.courseId == courseId) return record;
    }
    return null;
  }

  Future<void> deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_webIndexKey);
      return;
    }
    final directory = await certificatesDirectory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> _writeIndex(List<CertificateRecord> records) async {
    final payload = jsonEncode(records.map((item) => item.toJson()).toList());
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_webIndexKey, payload);
      return;
    }
    final directory = await certificatesDirectory();
    final index = File('${directory.path}${Platform.pathSeparator}index.json');
    await index.writeAsString(payload, flush: true);
  }
}
