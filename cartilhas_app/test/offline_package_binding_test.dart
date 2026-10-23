import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cartilhas_app/features/ead_offline/offline_package_binding.dart';
import 'package:cartilhas_app/features/ead_offline/offline_package_manifest.dart';
import 'package:cartilhas_app/features/ead_offline/offline_package_store.dart';

class ApprovedFixture implements VerifiedOfflineReleaseAuthority {
  @override
  Future<bool> verify(OfflinePackageManifest manifest) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory support;
  final bytes = [1, 2, 3];
  final manifest = OfflinePackageManifest.parse({
    'schema_version': 1,
    'course_id': 12,
    'lesson_id': 13,
    'content_revision': 'a' * 64,
    'mobile_content': true,
    'rights_approved': true,
    'mp4': {
      'url':
          'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/fixture.mp4',
      'length': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
    },
  });

  setUp(() async {
    support = await Directory.systemTemp.createTemp('tds-binding-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getApplicationSupportDirectory');
          return support.path;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await support.delete(recursive: true);
  });

  test(
    'fresh application support creates parent and installs verified package',
    () async {
      final parent = Directory('${support.path}/ead_offline');
      expect(await parent.exists(), isFalse);
      final store = await applicationOfflinePackageStore(
        namespace: 'qa_fresh',
        authority: ApprovedFixture(),
        download: (_) => Stream.value(bytes),
      );
      expect(await parent.exists(), isTrue);
      expect(await store.root.exists(), isFalse);
      await store.install(manifest);
      final file = await store.read(manifest);
      expect(await file!.readAsBytes(), bytes);
      expect(file.path, startsWith(store.root.path));
    },
  );

  test(
    'default denial creates no namespace or asset and performs no download',
    () async {
      var calls = 0;
      final store = await applicationOfflinePackageStore(
        download: (_) {
          calls++;
          return Stream.value(bytes);
        },
      );
      await expectLater(
        store.install(manifest),
        throwsA(
          isA<OfflinePackageException>().having(
            (e) => e.code,
            'code',
            'release_denied',
          ),
        ),
      );
      expect(calls, 0);
      expect(await store.root.exists(), isFalse);
    },
  );

  test('reuses existing parent without changing another namespace', () async {
    final sentinel = File('${support.path}/ead_offline/other/sentinel');
    await sentinel.parent.create(recursive: true);
    await sentinel.writeAsString('keep');
    await applicationOfflinePackageStore(namespace: 'new');
    expect(await sentinel.readAsString(), 'keep');
  });

  test('rejects regular file in parent location', () async {
    final file = File('${support.path}/ead_offline');
    await file.writeAsString('keep');
    await expectLater(
      applicationOfflinePackageStore(),
      throwsA(
        isA<OfflinePackageException>().having(
          (e) => e.code,
          'code',
          'unsafe_path',
        ),
      ),
    );
    expect(await file.readAsString(), 'keep');
  });

  test(
    'rejects symlink parent without writing outside support',
    () async {
      final outside = await Directory.systemTemp.createTemp('tds-outside-');
      addTearDown(() => outside.delete(recursive: true));
      final link = Link('${support.path}/ead_offline');
      await link.create(outside.path);
      addTearDown(() async {
        if (await link.exists()) await link.delete();
      });
      await expectLater(
        applicationOfflinePackageStore(),
        throwsA(
          isA<OfflinePackageException>().having(
            (e) => e.code,
            'code',
            'unsafe_path',
          ),
        ),
      );
      expect(await outside.list().isEmpty, isTrue);
    },
    skip: Platform.isWindows
        ? 'Windows link privilege not assumed; Linux CI exercises real symlink'
        : false,
  );

  test('rejects unsafe namespace before creating parent', () async {
    await expectLater(
      applicationOfflinePackageStore(namespace: '../escape'),
      throwsArgumentError,
    );
    expect(await Directory('${support.path}/ead_offline').exists(), isFalse);
  });
}
