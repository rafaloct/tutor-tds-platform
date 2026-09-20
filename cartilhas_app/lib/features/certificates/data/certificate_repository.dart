import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/certificate_record.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();

class CertificateRepository {
  final DocumentsDirectoryProvider _documentsDirectoryProvider;

  CertificateRepository({
    DocumentsDirectoryProvider? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  Future<Directory> certificatesDirectory() async {
    final documents = await _documentsDirectoryProvider();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}certificates',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<List<CertificateRecord>> loadAll() async {
    final directory = await certificatesDirectory();
    final index = File('${directory.path}${Platform.pathSeparator}index.json');
    if (!await index.exists()) return [];

    final decoded = jsonDecode(await index.readAsString());
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
    final directory = await certificatesDirectory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> _writeIndex(List<CertificateRecord> records) async {
    final directory = await certificatesDirectory();
    final index = File('${directory.path}${Platform.pathSeparator}index.json');
    await index.writeAsString(
      jsonEncode(records.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }
}
