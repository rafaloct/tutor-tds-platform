import 'dart:convert';

import 'package:crypto/crypto.dart';

class CertificateRecord {
  final int schemaVersion;
  final String id;
  final String issuer;
  final String holderName;
  final String courseId;
  final String courseTitle;
  final DateTime issuedAt;
  final int answeredQuestions;
  final int totalQuestions;
  final Uri verificationUrl;
  final String hash;
  final String signature;
  final String? filePath;

  const CertificateRecord({
    required this.schemaVersion,
    required this.id,
    required this.issuer,
    required this.holderName,
    required this.courseId,
    required this.courseTitle,
    required this.issuedAt,
    required this.answeredQuestions,
    required this.totalQuestions,
    required this.verificationUrl,
    required this.hash,
    required this.signature,
    this.filePath,
  });

  factory CertificateRecord.fromJson(Map<String, dynamic> json) {
    return CertificateRecord(
      schemaVersion: json['schemaVersion'] as int,
      id: json['id'] as String,
      issuer: json['issuer'] as String,
      holderName: json['holderName'] as String,
      courseId: json['courseId'] as String,
      courseTitle: json['courseTitle'] as String,
      issuedAt: DateTime.parse(json['issuedAt'] as String).toUtc(),
      answeredQuestions: json['answeredQuestions'] as int,
      totalQuestions: json['totalQuestions'] as int,
      verificationUrl: Uri.parse(json['verificationUrl'] as String),
      hash: json['hash'] as String,
      signature: json['signature'] as String,
      filePath: json['filePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    ...canonicalData,
    'hash': hash,
    'signature': signature,
    if (filePath != null) 'filePath': filePath,
  };

  Map<String, dynamic> get canonicalData => {
    'schemaVersion': schemaVersion,
    'id': id,
    'issuer': issuer,
    'holderName': holderName,
    'courseId': courseId,
    'courseTitle': courseTitle,
    'issuedAt': issuedAt.toUtc().toIso8601String(),
    'answeredQuestions': answeredQuestions,
    'totalQuestions': totalQuestions,
    'verificationUrl': verificationUrl.toString(),
  };

  String get computedHash =>
      sha256.convert(utf8.encode(jsonEncode(canonicalData))).toString();

  bool get hasValidLocalHash =>
      hash.length == 64 && computedHash.toLowerCase() == hash.toLowerCase();

  CertificateRecord copyWith({String? filePath}) => CertificateRecord(
    schemaVersion: schemaVersion,
    id: id,
    issuer: issuer,
    holderName: holderName,
    courseId: courseId,
    courseTitle: courseTitle,
    issuedAt: issuedAt,
    answeredQuestions: answeredQuestions,
    totalQuestions: totalQuestions,
    verificationUrl: verificationUrl,
    hash: hash,
    signature: signature,
    filePath: filePath ?? this.filePath,
  );
}
