import 'dart:io';

import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_youtube_player_screen.dart';
import 'package:cartilhas_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = 'FG14ksTaMCE';

  test('ID exato, URL canônica e reprodução manual', () {
    expect(EadYoutubePolicy.validId(id), isTrue);
    expect(EadYoutubePolicy.validId('abc_DEF-123'), isTrue);
    for (final invalid in <String?>[
      null, '', '$id\n', '$id ', ' $id', '$id/', 'short',
      'https://youtube.com/watch?v=$id', '<script>bad', 'áG14ksTaMCE',
    ]) {
      expect(EadYoutubePolicy.validId(invalid), isFalse, reason: '$invalid');
    }
    expect(EadYoutubePolicy.embed(id).toString(),
        'https://www.youtube-nocookie.com/embed/$id?autoplay=0&playsinline=1&cc_load_policy=1&rel=0');
    expect(EadYoutubePolicy.external(id).toString(),
        'https://www.youtube.com/watch?v=$id');
    expect(() => EadYoutubePolicy.embed('invalid'), throwsArgumentError);
    expect(() => EadYoutubePolicy.external('invalid'), throwsArgumentError);
  });

  test('allowlist bloqueia esquema, host, porta, redirect e outro vídeo', () {
    final canonical = EadYoutubePolicy.embed(id).toString();
    expect(EadYoutubePolicy.allows(canonical, id), isTrue);
    for (final url in [
      'javascript:alert(1)', 'file:///video', 'data:text/html,test',
      'intent://youtube', 'about:blank',
      canonical.replaceFirst('https:', 'http:'),
      canonical.replaceFirst('www.youtube-nocookie.com', 'evil.example'),
      canonical.replaceFirst('www.youtube-nocookie.com', 'www.youtube-nocookie.com.evil.example'),
      canonical.replaceFirst('www.youtube-nocookie.com', 'evil@www.youtube-nocookie.com'),
      canonical.replaceFirst('.com/', '.com:443/'),
      canonical.replaceFirst(id, 'abcdefghijk'),
      '$canonical&redirect=https://evil.example', '$canonical#fragment',
      canonical.replaceFirst('/embed/', '/watch/'),
      'https://www.youtube.com/watch?v=$id',
    ]) {
      expect(EadYoutubePolicy.allows(url, id), isFalse, reason: url);
    }
  });

  test('player editorial não importa domínio de mídia nem eventos', () {
    final source = File('lib/features/ead_catalog/learning_path/ead_youtube_player_screen.dart').readAsStringSync();
    expect(source, isNot(contains("import '../../media/")));
    expect(source, isNot(contains('MediaEventTracker(')));
    expect(source, isNot(contains('MediaProgressRepository(')));
    expect(source, isNot(contains('MediaItem(')));
    expect(source, isNot(contains('addJavaScriptChannel')));
  });

  for (final dark in [false, true]) {
    testWidgets('erro e fallback explícito, tema ${dark ? "escuro" : "claro"}', (tester) async {
      VoidCallback? fail;
      Uri? opened;
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: EadYoutubePlayerScreen(
          videoId: id, lessonTitle: 'Aula autorizada', courseTitle: 'Curso SAF',
          viewFactory: (_, ready, error) {
            fail = error;
            return const SizedBox.expand();
          },
          openExternal: (url) async { opened = url; return false; },
        ),
      ));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(opened, isNull);
      fail!();
      await tester.pump();
      expect(find.textContaining('Vídeo indisponível'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(opened, isNull);
      await tester.tap(find.text('Abrir no YouTube'));
      await tester.pump();
      expect(opened, EadYoutubePolicy.external(id));
      expect(find.text('Não foi possível abrir o YouTube.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('documento pronto remove loader sem lançar URL', (tester) async {
    VoidCallback? ready;
    await tester.pumpWidget(MaterialApp(home: EadYoutubePlayerScreen(
      videoId: id, lessonTitle: 'Aula', courseTitle: 'Curso',
      viewFactory: (_, onReady, onError) {
        ready = onReady;
        return const SizedBox.expand();
      },
      openExternal: (_) async => throw StateError('Abertura automática'),
    )));
    ready!();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(AspectRatio), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ID inválido não cria WebView nem fallback', (tester) async {
    await tester.pumpWidget(MaterialApp(home: EadYoutubePlayerScreen(
      videoId: 'invalid', lessonTitle: 'Aula', courseTitle: 'Curso',
      viewFactory: (_, onReady, onError) => throw StateError('Não autorizado'),
    )));
    expect(find.textContaining('Vídeo indisponível'), findsOneWidget);
    expect(find.text('Abrir no YouTube'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
