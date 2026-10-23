import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'offline_package_manifest.dart';

/// Reads current public editorial metadata; never grants download authority.
/// No cache: a removed/revoked manifest must not fall back to an older release.
class OfflineManifestRepository {
  OfflineManifestRepository({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  static const _timeout = Duration(seconds: 12);
  static const _maxBytes = 4096;

  static Uri manifestUrl(int courseId, int lessonId) {
    if (courseId <= 0 ||
        courseId > 100000000 ||
        lessonId <= 0 ||
        lessonId > 100000000) {
      throw const FormatException('Invalid offline lesson identity');
    }
    return Uri.https(
      'ead.ipexdesenvolvimento.cloud',
      '/wp-json/tds-learning/v1/courses/$courseId/lessons/$lessonId/offline-manifest',
    );
  }

  Future<OfflinePackageManifest> fetch(int courseId, int lessonId) async {
    final url = manifestUrl(courseId, lessonId);
    final client = _clientFactory();
    try {
      // The client is owned per operation, so timeout also closes transport.
      return await _fetch(client, url, courseId, lessonId).timeout(_timeout);
    } on Object {
      // No server payload, URL or transport detail in user-facing errors.
      throw const FormatException('Offline manifest unavailable');
    } finally {
      client.close();
    }
  }

  Future<OfflinePackageManifest> _fetch(
    http.Client client,
    Uri url,
    int courseId,
    int lessonId,
  ) async {
    final request = http.Request('GET', url)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    final response = await client.send(request);
    if (response.statusCode != 200 ||
        response.isRedirect ||
        (response.contentLength != null &&
            response.contentLength! > _maxBytes)) {
      throw const FormatException('Invalid manifest response');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(_timeout)) {
      if (bytes.length + chunk.length > _maxBytes) {
        throw const FormatException('Manifest too large');
      }
      bytes.addAll(chunk);
    }
    if (response.contentLength != null &&
        response.contentLength != bytes.length) {
      throw const FormatException('Truncated manifest');
    }
    final manifest = OfflinePackageManifest.fromJson(utf8.decode(bytes));
    if (manifest.courseId != courseId || manifest.lessonId != lessonId) {
      throw const FormatException('Manifest identity mismatch');
    }
    return manifest;
  }
}
