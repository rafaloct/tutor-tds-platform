import 'dart:io';

import 'package:cartilhas_app/features/ead_offline/offline_package_store.dart';
import 'package:cartilhas_app/features/ead_offline/synthetic_offline_qa_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late Directory root;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ead-qa-widget-');
    root = Directory('${temp.path}${Platform.pathSeparator}private');
  });
  tearDown(() async => temp.delete(recursive: true));

  OfflinePackageStore store({bool network = true}) => OfflinePackageStore(
    root: root,
    authorize: (_) async => true,
    download: network
        ? SyntheticOfflineQa.fixtureStream
        : (_) => throw StateError('network forbidden'),
  );

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('UI state did not arrive: $finder');
  }

  testWidgets(
    'prepares, resumes without network, exposes captions and revokes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SyntheticOfflineQaScreen(testStore: store())),
      );
      await waitFor(tester, find.textContaining('ainda não preparado'));
      expect(find.text('Assistir offline'), findsOneWidget);
      await tester.tap(find.text('Preparar offline'));
      await waitFor(tester, find.textContaining('Pronto para modo avião'));
      expect(find.textContaining('Pronto para modo avião'), findsOneWidget);
      final captions = await store(
        network: false,
      ).read(SyntheticOfflineQa.manifest, captions: true);
      expect(await captions!.readAsString(), contains('WEBVTT'));
      expect(await captions.readAsString(), contains('Vídeo sintético'));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: SyntheticOfflineQaScreen(testStore: store(network: false)),
        ),
      );
      await waitFor(tester, find.textContaining('Pronto para modo avião'));
      expect(find.textContaining('Pronto para modo avião'), findsOneWidget);
      await tester.tap(find.text('Remover offline'));
      await waitFor(tester, find.textContaining('ainda não preparado'));
      expect(
        await store(network: false).read(SyntheticOfflineQa.manifest),
        isNull,
      );
    },
  );

  testWidgets('failed stream reports error and leaves no ready file', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SyntheticOfflineQaScreen(testStore: store(network: false)),
      ),
    );
    await waitFor(tester, find.textContaining('ainda não preparado'));
    await tester.tap(find.text('Preparar offline'));
    await waitFor(tester, find.textContaining('Falha ao preparar'));
    expect(find.textContaining('Falha ao preparar'), findsOneWidget);
    expect(
      await store(network: false).read(SyntheticOfflineQa.manifest),
      isNull,
    );
  });
}
