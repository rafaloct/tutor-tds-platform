import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cartilhas_app/features/ead_offline/editorial_offline_release_authority.dart';
import 'package:cartilhas_app/features/ead_offline/offline_manifest_repository.dart';
import 'package:cartilhas_app/features/ead_offline/offline_package_binding.dart';
import 'package:cartilhas_app/features/ead_offline/offline_package_manifest.dart';
import 'package:cartilhas_app/features/ead_offline/offline_package_store.dart';

Map<String, dynamic> payload() => {
  'schema_version': 1,
  'course_id': 11,
  'lesson_id': 12,
  'content_revision': 'a' * 64,
  'mobile_content': true,
  'rights_approved': true,
  'title': 'Aula',
  'mp4': {
    'url':
        'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/test.mp4',
    'length': 5,
    'sha256': 'b' * 64,
  },
  'vtt': {
    'url':
        'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/test.vtt',
    'length': 8,
    'sha256': 'c' * 64,
  },
};

EditorialOfflineReleaseAuthority authority(
  Future<http.Response> Function(http.Request) handler,
) => EditorialOfflineReleaseAuthority(
  repository: OfflineManifestRepository(
    clientFactory: () => MockClient(handler),
  ),
);

void main() {
  test(
    'default authority still denies an approved-looking local manifest',
    () async {
      expect(
        await const DenyOfflineReleaseAuthority().verify(
          OfflinePackageManifest.parse(payload()),
        ),
        isFalse,
      );
    },
  );

  test('fresh server match accepts independent of JSON key ordering', () async {
    final candidate = OfflinePackageManifest.parse(payload());
    var calls = 0;
    final check = authority((request) async {
      calls++;
      expect(request.url, OfflineManifestRepository.manifestUrl(11, 12));
      final reversed = Map<String, dynamic>.fromEntries(
        payload().entries.toList().reversed,
      );
      return http.Response(jsonEncode(reversed), 200);
    });
    expect(await check.verify(candidate), isTrue);
    expect(await check.verify(candidate), isTrue);
    expect(calls, 2);
  });

  final mutations = <String, void Function(Map<String, dynamic>)>{
    'course': (p) => p['course_id'] = 99,
    'lesson': (p) => p['lesson_id'] = 99,
    'revision': (p) => p['content_revision'] = 'd' * 64,
    'mp4 url': (p) => p['mp4']['url'] =
        'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/replaced.mp4',
    'mp4 length': (p) => p['mp4']['length'] = 6,
    'mp4 hash': (p) => p['mp4']['sha256'] = 'd' * 64,
    'vtt removed': (p) => p.remove('vtt'),
    'vtt length': (p) => p['vtt']['length'] = 9,
    'vtt hash': (p) => p['vtt']['sha256'] = 'd' * 64,
    'title': (p) => p['title'] = 'Atualizada',
    'rights revoked': (p) => p['rights_approved'] = false,
    'mobile revoked': (p) => p['mobile_content'] = false,
  };
  for (final entry in mutations.entries) {
    test(
      'denies changed ${entry.key} even if approval flags look valid',
      () async {
        final current = payload();
        entry.value(current);
        expect(
          await authority(
            (_) async => http.Response(jsonEncode(current), 200),
          ).verify(OfflinePackageManifest.parse(payload())),
          isFalse,
        );
      },
    );
  }

  test('server revocation denies previously accepted candidate', () async {
    var calls = 0;
    final check = authority(
      (_) async => ++calls == 1
          ? http.Response(jsonEncode(payload()), 200)
          : http.Response('', 404),
    );
    final candidate = OfflinePackageManifest.parse(payload());
    expect(await check.verify(candidate), isTrue);
    expect(await check.verify(candidate), isFalse);
  });

  test('transport outage fails closed', () async {
    expect(
      await authority(
        (_) async => throw const SocketException('unavailable'),
      ).verify(OfflinePackageManifest.parse(payload())),
      isFalse,
    );
  });

  test(
    'store denies before creating storage or downloading on stale release',
    () async {
      final parent = await Directory.systemTemp.createTemp('tds-authority-');
      addTearDown(() => parent.delete(recursive: true));
      final root = Directory('${parent.path}/uncreated');
      var downloads = 0;
      final check = authority((_) async => http.Response('', 404));
      final store = OfflinePackageStore(
        root: root,
        authorize: check.verify,
        download: (_) {
          downloads++;
          return const Stream.empty();
        },
      );
      await expectLater(
        store.install(OfflinePackageManifest.parse(payload())),
        throwsA(
          isA<OfflinePackageException>().having(
            (e) => e.code,
            'code',
            'release_denied',
          ),
        ),
      );
      expect(downloads, 0);
      expect(await root.exists(), isFalse);
    },
  );
}
