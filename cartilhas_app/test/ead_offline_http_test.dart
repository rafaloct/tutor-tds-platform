import 'dart:async';
import 'dart:io';

import 'package:cartilhas_app/features/ead_offline/offline_http_download.dart';
import 'package:cartilhas_app/features/ead_offline/offline_package_store.dart';
import 'package:flutter_test/flutter_test.dart';

final allowed = Uri.parse(
  'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/test.mp4',
);

class _Client implements HttpClient {
  _Client(this.response);
  final _Response response;
  bool contacted = false;
  bool closed = false;
  late _Request request;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    contacted = true;
    request = _Request(response);
    return request;
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.response);
  final _Response response;
  bool? redirects;
  @override
  set followRedirects(bool value) => redirects = value;
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void removeAll(String name) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends StreamView<List<int>> implements HttpClientResponse {
  _Response({
    required this.statusCode,
    required this.contentLength,
    required List<List<int>> chunks,
  }) : super(Stream.fromIterable(chunks));
  @override
  final int statusCode;
  @override
  final int contentLength;
  @override
  bool get isRedirect => statusCode >= 300 && statusCode < 400;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('rejects hostile URLs before opening a connection', () async {
    final client = _Client(
      _Response(
        statusCode: 200,
        contentLength: 1,
        chunks: [
          [1],
        ],
      ),
    );
    final download = OfflineHttpDownload(clientFactory: () => client);
    for (final url in [
      'http://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/test.mp4',
      'https://evil.example/wp-content/uploads/tutor-tds/test.mp4',
      'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/%2e%2e/test.mp4',
      'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/test.mp4?token=x',
    ]) {
      await expectLater(
        download(Uri.parse(url)).toList(),
        throwsA(isA<OfflinePackageException>()),
      );
    }
    expect(client.contacted, isFalse);
  });

  test('rejects redirect without following it', () async {
    final client = _Client(
      _Response(statusCode: 302, contentLength: 0, chunks: []),
    );
    await expectLater(
      OfflineHttpDownload(clientFactory: () => client)(allowed).toList(),
      throwsA(isA<OfflinePackageException>()),
    );
    expect(client.request.redirects, isFalse);
    expect(client.closed, isTrue);
  });

  test('rejects missing, oversized and incorrect content length', () async {
    for (final response in [
      _Response(statusCode: 200, contentLength: -1, chunks: []),
      _Response(statusCode: 200, contentLength: 500 * 1024 * 1024, chunks: []),
      _Response(
        statusCode: 200,
        contentLength: 1,
        chunks: [
          [1, 2],
        ],
      ),
      _Response(
        statusCode: 200,
        contentLength: 2,
        chunks: [
          [1],
        ],
      ),
    ]) {
      await expectLater(
        OfflineHttpDownload(clientFactory: () => _Client(response))(
          allowed,
        ).toList(),
        throwsA(isA<OfflinePackageException>()),
      );
    }
  });

  test('accepts exact anonymous stream', () async {
    final client = _Client(
      _Response(
        statusCode: 200,
        contentLength: 2,
        chunks: [
          [1],
          [2],
        ],
      ),
    );
    expect(
      await OfflineHttpDownload(clientFactory: () => client)(allowed).toList(),
      [
        [1],
        [2],
      ],
    );
    expect(client.request.redirects, isFalse);
    expect(client.closed, isTrue);
  });
}
