import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cartilhas_app/features/ead_offline/offline_manifest_repository.dart';

Map<String, Object> payload({int course = 11, int lesson = 12}) => {
  'schema_version': 1,
  'course_id': course,
  'lesson_id': lesson,
  'content_revision': 'a' * 64,
  'mobile_content': true,
  'rights_approved': true,
  'mp4': {
    'url':
        'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/test.mp4',
    'length': 5,
    'sha256': 'b' * 64,
  },
};

class TrackedClient extends MockClient {
  TrackedClient(super.handler);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}

class StreamClient extends http.BaseClient {
  StreamClient(this.response);
  final http.StreamedResponse response;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      response;
  @override
  void close() {
    closed = true;
  }
}

void main() {
  for (final response in [
    http.StreamedResponse(Stream.value(List.filled(4097, 32)), 200),
    http.StreamedResponse(
      Stream.fromIterable([List.filled(2048, 32), List.filled(2049, 32)]),
      200,
    ),
    http.StreamedResponse(Stream.value([123]), 200, contentLength: 10),
    http.StreamedResponse(Stream.value([255]), 200),
    http.StreamedResponse(
      Stream.error(StateError('private transport error')),
      200,
    ),
    http.StreamedResponse(const Stream.empty(), 200, contentLength: 4097),
  ]) {
    test('stream bounds, truncation, decoding and transport failure', () async {
      final client = StreamClient(response);
      await expectLater(
        OfflineManifestRepository(clientFactory: () => client).fetch(11, 12),
        throwsFormatException,
      );
      expect(client.closed, isTrue);
    });
  }

  test(
    'canonical anonymous request, strict payload and owned client cleanup',
    () async {
      final client = TrackedClient((request) async {
        expect(
          request.url.toString(),
          'https://ead.ipexdesenvolvimento.cloud/wp-json/tds-learning/v1/courses/11/lessons/12/offline-manifest',
        );
        expect(request.method, 'GET');
        expect(request.followRedirects, isFalse);
        expect(request.headers, {'Accept': 'application/json'});
        return http.Response(jsonEncode(payload()), 200);
      });
      final manifest = await OfflineManifestRepository(
        clientFactory: () => client,
      ).fetch(11, 12);
      expect(manifest.lessonId, 12);
      expect(client.closed, isTrue);
    },
  );

  for (final ids in [(0, 12), (11, -1), (100000001, 12)]) {
    test('invalid identity $ids never creates transport', () async {
      final repository = OfflineManifestRepository(
        clientFactory: () => throw StateError('transport'),
      );
      await expectLater(
        repository.fetch(ids.$1, ids.$2),
        throwsFormatException,
      );
    });
  }

  for (final value in [
    payload(course: 13),
    payload(lesson: 13),
    {...payload(), 'rights_approved': false},
    {...payload(), 'unknown': true},
  ]) {
    test('rejects mismatched or untrusted payload $value', () async {
      final client = TrackedClient(
        (_) async => http.Response(jsonEncode(value), 200),
      );
      await expectLater(
        OfflineManifestRepository(clientFactory: () => client).fetch(11, 12),
        throwsFormatException,
      );
      expect(client.closed, isTrue);
    });
  }

  for (final status in [301, 302, 304, 401, 403, 404, 500]) {
    test('status $status fails closed', () async {
      final client = TrackedClient(
        (_) async => http.Response(jsonEncode(payload()), status),
      );
      await expectLater(
        OfflineManifestRepository(clientFactory: () => client).fetch(11, 12),
        throwsFormatException,
      );
      expect(client.closed, isTrue);
    });
  }

  test('does not resurrect previous success after revocation', () async {
    var calls = 0;
    final repository = OfflineManifestRepository(
      clientFactory: () => MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response(jsonEncode(payload()), 200)
            : http.Response('', 404);
      }),
    );
    await repository.fetch(11, 12);
    await expectLater(repository.fetch(11, 12), throwsFormatException);
    expect(calls, 2);
  });

  for (final body in ['{', '[]', 'x' * 4097]) {
    test(
      'rejects malformed or oversized response length ${body.length}',
      () async {
        final repository = OfflineManifestRepository(
          clientFactory: () =>
              MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(repository.fetch(11, 12), throwsFormatException);
      },
    );
  }
}
