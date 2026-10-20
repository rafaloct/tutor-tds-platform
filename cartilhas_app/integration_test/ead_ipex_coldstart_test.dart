import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_ipex_video_player_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// Files reviewed for the #308 pilot. No editorial state is changed here.
final _video = Uri.parse(
  'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/'
  'tutor-tds/v2-20261016/agricultura_sustentavel/'
  '01_agroecologia_cerrado_v2_acessivel_FHD.mp4',
);
final _captions = Uri.parse(
  'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/'
  'tutor-tds/v2-20261016/agricultura_sustentavel/'
  '01_agroecologia_cerrado.vtt',
);

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition,
  String failure, {
  int seconds = 60,
}) async {
  for (var elapsed = 0; elapsed < seconds; elapsed++) {
    await tester.pump(const Duration(seconds: 1));
    if (find.textContaining('Vídeo indisponível').evaluate().isNotEmpty) {
      fail('Player failed while waiting for $failure');
    }
    if (condition()) return;
  }
  fail('Timed out waiting for $failure');
}

Object? _decodeJavaScript(Object value) {
  Object? decoded = value;
  for (var i = 0; i < 3 && decoded is String; i++) {
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      break;
    }
  }
  return decoded;
}

Future<Map<String, dynamic>> _mediaState(WebViewController controller) async {
  final value = await controller.runJavaScriptReturningResult(
    'JSON.stringify((() => {const v=document.getElementById("lesson-video");'
    'const q=v.getVideoPlaybackQuality?.();'
    'const b=[];for(let i=0;i<v.buffered.length;i++)b.push([v.buffered.start(i),v.buffered.end(i)]);'
    'return {time:v.currentTime,ready:v.readyState,network:v.networkState,'
    'paused:v.paused,error:v.error?.code??null,buffered:b,'
    'frames:q?.totalVideoFrames??v.webkitDecodedFrameCount??null,'
    'dropped:q?.droppedVideoFrames??null};})())',
  );
  final decoded = _decodeJavaScript(value);
  if (decoded is! Map<String, dynamic>) {
    fail('Unexpected JavaScript media state type: ${decoded.runtimeType}');
  }
  return decoded;
}

Future<num> _number(WebViewController controller, String expression) async {
  final value = _decodeJavaScript(
    await controller.runJavaScriptReturningResult(expression),
  );
  if (value is num) return value;
  fail('Unexpected JavaScript number type: ${value.runtimeType}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // This integration APK is built only for the isolated QA package. Never
    // expose Chromium inspection in a production or release build.
    if (kDebugMode &&
        const bool.fromEnvironment('DYNAMIC_QA_ISOLATED_PACKAGE')) {
      await AndroidWebViewController.enableDebugging(true);
      debugPrint('IPEX_QA_CDP_ENABLED');
    }
  });

  testWidgets(
    'Android first WebView and warm reopen play MP4 with VTT',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      for (final scenario in ['first_in_process', 'warm_reopen']) {
        final events = <String>[];
        WebViewController? controller;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EadIpexVideoPlayerScreen(
                          video: _video,
                          captions: _captions,
                          lessonTitle: 'QA $scenario',
                          onMediaEvent: events.add,
                          onController: (value) => controller = value,
                        ),
                      ),
                    ),
                    child: const Text('Abrir aula QA'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir aula QA'));
        await tester.pump(const Duration(milliseconds: 350));

        await _waitFor(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'HTML page finish in $scenario',
          seconds: 150,
        );
        await _waitFor(
          tester,
          () =>
              events.contains('mp4_metadata') && events.contains('vtt_loaded'),
          'MP4 metadata and VTT load in $scenario',
        );
        expect(controller, isNotNull);
        final activeController = controller!;
        final webView = find.byType(WebViewWidget);
        expect(webView, findsOneWidget);
        final rect = tester.getRect(webView);
        final videoCenter = Offset(
          rect.center.dx,
          rect.top + rect.width * 9 / 32,
        );
        debugPrint('IPEX_QA_CDP_PRE_PLAY scenario=$scenario');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 10)),
        );
        await tester.tapAt(videoCenter);
        await _waitFor(
          tester,
          () => events.contains('mp4_playing'),
          'touch-triggered MP4 playing in $scenario',
          seconds: 15,
        );
        var advanced = false;
        for (var second = 1; second <= 20; second++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 1)),
          );
          final state = await _mediaState(activeController);
          debugPrint(
            'IPEX_QA_MEDIA_STATE scenario=$scenario second=$second state=$state',
          );
          if ((state['time'] as num) > 0.25 &&
              ((state['frames'] as num?) ?? 0) > 0) {
            advanced = true;
            break;
          }
        }
        expect(advanced, isTrue, reason: 'No time and decoded-frame advance');
        debugPrint('IPEX_QA_PLAYBACK_CONFIRMED scenario=$scenario');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 3)),
        );
        final cueCount = await _number(
          activeController,
          'document.getElementById("lesson-video").textTracks[0].cues.length',
        );
        expect(cueCount, 35);
        await activeController.runJavaScript(
          'document.getElementById("lesson-video").currentTime=9',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 2)),
        );
        final visibleCue = await _number(
          activeController,
          'document.getElementById("caption-text").textContent.trim().length',
        );
        expect(visibleCue, greaterThan(0));

        // Caption button is below the 16:9 video inside the WebView.
        final toggle = Offset(
          rect.left + 85,
          rect.top + rect.width * 9 / 16 + 30,
        );
        await tester.tapAt(toggle);
        await tester.pump(const Duration(milliseconds: 400));
        final hidden = await activeController.runJavaScriptReturningResult(
          'document.getElementById("caption-toggle").getAttribute("aria-pressed")',
        );
        expect(_decodeJavaScript(hidden).toString(), 'false');
        final hiddenCue = await _number(
          activeController,
          'document.getElementById("caption-text").textContent.trim().length',
        );
        expect(hiddenCue, 0);
        await tester.tapAt(toggle);
        await tester.pump(const Duration(milliseconds: 400));
        final shown = await activeController.runJavaScriptReturningResult(
          'document.getElementById("caption-toggle").getAttribute("aria-pressed")',
        );
        expect(_decodeJavaScript(shown).toString(), 'true');
        final restoredCue = await _number(
          activeController,
          'document.getElementById("caption-text").textContent.trim().length',
        );
        expect(restoredCue, greaterThan(0));

        // Pause is programmatic; playback and caption toggles use real taps.
        await activeController.runJavaScript(
          'document.getElementById("lesson-video").pause()',
        );
        final pausedState = await _mediaState(activeController);
        expect(
          _decodeJavaScript(
            await activeController.runJavaScriptReturningResult(
              'document.getElementById("lesson-video").paused',
            ),
          ),
          true,
        );
        await activeController.runJavaScript(
          'document.getElementById("lesson-video").play()',
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 2)),
        );
        final resumedState = await _mediaState(activeController);
        expect(resumedState['paused'], false);
        expect(
          resumedState['time'] as num,
          greaterThan((pausedState['time'] as num) + 0.25),
          reason: 'Resume must advance media time',
        );
        expect(
          resumedState['frames'] as num,
          greaterThan(pausedState['frames'] as num),
          reason: 'Resume must present decoded frames',
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Abrir aula QA'), findsOneWidget);
      }
    },
    timeout: const Timeout(Duration(minutes: 9)),
  );
}
