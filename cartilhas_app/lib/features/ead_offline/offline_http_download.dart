import 'dart:async';
import 'dart:io';

import 'offline_package_manifest.dart';
import 'offline_package_store.dart';

/// Anonymous, bounded transport. The store checks the manifest length and hash.
class OfflineHttpDownload {
  OfflineHttpDownload({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;

  Stream<List<int>> call(Uri url) async* {
    // Validate again at the transport boundary, even for injected callers.
    final extension = url.path.endsWith('.vtt') ? 'vtt' : 'mp4';
    try {
      OfflineAsset.parse({
        'url': url.toString(),
        'length': 1,
        'sha256': '0' * 64,
      }, extension);
    } on FormatException {
      throw const OfflinePackageException('unsafe_url');
    }
    final client = _clientFactory();
    client.connectionTimeout = const Duration(seconds: 10);
    client.idleTimeout = const Duration(seconds: 10);
    client.autoUncompress = false;
    try {
      final request = await client
          .getUrl(url)
          .timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      request.persistentConnection = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.headers.removeAll(HttpHeaders.cookieHeader);
      request.headers.removeAll(HttpHeaders.authorizationHeader);
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.isRedirect || response.statusCode != HttpStatus.ok) {
        throw const OfflinePackageException('http_denied');
      }
      final declared = response.contentLength;
      final maximum = extension == 'mp4'
          ? OfflinePackageManifest.maxMp4Bytes
          : OfflinePackageManifest.maxPackageBytes;
      if (declared < 0 || declared > maximum) {
        throw const OfflinePackageException('size_mismatch');
      }
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        received += chunk.length;
        if (received > declared) {
          throw const OfflinePackageException('size_mismatch');
        }
        yield chunk;
      }
      if (received != declared) {
        throw const OfflinePackageException('size_mismatch');
      }
    } finally {
      client.close(force: true);
    }
  }
}
