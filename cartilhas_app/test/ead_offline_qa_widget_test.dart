import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/ead_offline/offline_package_store.dart';
import 'package:cartilhas_app/features/ead_offline/synthetic_offline_qa_screen.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late Directory root;
  late List<Future<void>> operations;
  var networkCalls = 0;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ead-qa-widget-');
    root = Directory('${temp.path}${Platform.pathSeparator}private');
    operations = [];
    networkCalls = 0;
  });
  tearDown(() async => temp.delete(recursive: true));

  OfflinePackageStore store({bool network = true}) => OfflinePackageStore(
    root: root,
    authorize: (_) async => true,
    download: network
        ? (url) {
            final path = url.path.endsWith('/synthetic.mp4')
                ? SyntheticOfflineQa.videoAsset
                : url.path.endsWith('/synthetic.vtt')
                ? SyntheticOfflineQa.captionAsset
                : throw StateError('unexpected fixture URL: $url');
            return File(path).openRead();
          }
        : (_) {
            networkCalls++;
            throw StateError('network forbidden');
          },
  );

  Widget screen(OfflinePackageStore packageStore) => MaterialApp(
    home: SyntheticOfflineQaScreen(
      testStore: packageStore,
      onOperation: (work) => operations.add(Zone.root.run(work)),
    ),
  );

  String status(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('offline-status'))).data!;

  Future<void> awaitOperation(WidgetTester tester, int index) async {
    expect(
      operations.length,
      greaterThan(index),
      reason: 'status: ${status(tester)}',
    );
    try {
      await tester.runAsync(
        () => operations[index].timeout(const Duration(seconds: 30)),
      );
    } on Object catch (error) {
      fail('operation $index failed: $error; status: ${status(tester)}');
    }
    await tester.pump();
  }

  Future<void> tapOperation(
    WidgetTester tester,
    String label,
    int index,
  ) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(label));
      expect(operations.length, greaterThan(index));
      await operations[index].timeout(const Duration(seconds: 30));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  Future<T> io<T>(WidgetTester tester, Future<T> Function() work) async =>
      (await tester.runAsync(() async => (value: await work())))!.value;

  Future<void> detach(WidgetTester tester) async {
    await io(
      tester,
      () => Future.wait(operations).timeout(const Duration(seconds: 30)),
    );
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets(
    'prepares, resumes without network, exposes captions and revokes',
    (tester) async {
      try {
        await tester.pumpWidget(screen(store()));
        await awaitOperation(tester, 0);
        expect(status(tester), contains('ainda não preparado'));
        await tapOperation(tester, 'Preparar offline', 1);
        expect(status(tester), contains('Pronto para modo avião'));
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Assistir offline'),
              )
              .onPressed,
          isNotNull,
        );

        final offlineStore = store(network: false);
        final video = await io(
          tester,
          () => offlineStore.read(SyntheticOfflineQa.manifest),
        );
        final captions = await io(
          tester,
          () => offlineStore.read(SyntheticOfflineQa.manifest, captions: true),
        );
        expect(
          video,
          isNotNull,
          reason: 'installed video; status: ${status(tester)}',
        );
        expect(
          captions,
          isNotNull,
          reason: 'installed captions; status: ${status(tester)}',
        );
        final videoBytes = await io(tester, video!.readAsBytes);
        final captionBytes = await io(tester, captions!.readAsBytes);
        expect(videoBytes.length, SyntheticOfflineQa.manifest.mp4.length);
        expect(
          sha256.convert(videoBytes).toString(),
          SyntheticOfflineQa.manifest.mp4.sha256,
        );
        expect(captionBytes.length, SyntheticOfflineQa.manifest.vtt!.length);
        expect(
          sha256.convert(captionBytes).toString(),
          SyntheticOfflineQa.manifest.vtt!.sha256,
        );
        expect(utf8.decode(captionBytes), contains('WEBVTT'));
        expect(utf8.decode(captionBytes), contains('Vídeo sintético'));

        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(screen(offlineStore));
        await awaitOperation(tester, 2);
        expect(status(tester), contains('Pronto para modo avião'));
        expect(networkCalls, 0);
        await tapOperation(tester, 'Remover offline', 3);
        expect(status(tester), contains('ainda não preparado'));
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Assistir offline'),
              )
              .onPressed,
          isNull,
        );
        expect(
          await io(
            tester,
            () => offlineStore.read(SyntheticOfflineQa.manifest),
          ),
          isNull,
        );
        expect(await io(tester, video.exists), isFalse);
        expect(await io(tester, captions.exists), isFalse);
        expect(networkCalls, 0);
      } finally {
        await detach(tester);
      }
    },
  );

  testWidgets('failed stream reports error and leaves no ready file', (
    tester,
  ) async {
    try {
      final offlineStore = store(network: false);
      await tester.pumpWidget(screen(offlineStore));
      await awaitOperation(tester, 0);
      expect(status(tester), contains('ainda não preparado'));
      await tapOperation(tester, 'Preparar offline', 1);
      expect(status(tester), contains('Falha ao preparar'));
      expect(
        await io(tester, () => offlineStore.read(SyntheticOfflineQa.manifest)),
        isNull,
      );
      expect(networkCalls, 1);
    } finally {
      await detach(tester);
    }
  });
}
