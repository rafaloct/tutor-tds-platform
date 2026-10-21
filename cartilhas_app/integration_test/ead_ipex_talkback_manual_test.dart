import 'dart:io';

import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_ipex_video_player_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// Human-only assistive QA fixture. The editorial route remains closed until
// each lesson is approved; this test never changes publication or student data.
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'keep authorized QA player open for Samsung TalkBack review',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      expect(kDebugMode, isTrue);
      expect(const bool.fromEnvironment('DYNAMIC_QA_ISOLATED_PACKAGE'), isTrue);
      await AndroidWebViewController.enableDebugging(true);

      final events = <String>[];
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
                        lessonTitle: 'Revisão acessível QA 1420',
                        onMediaEvent: events.add,
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

      for (var seconds = 0; seconds < 90; seconds++) {
        if (events.contains('mp4_metadata') && events.contains('vtt_loaded')) {
          break;
        }
        await tester.pump(const Duration(seconds: 1));
      }
      expect(events, contains('mp4_metadata'));
      expect(events, contains('vtt_loaded'));
      debugPrint('IPEX_QA_TALKBACK_READY media_metadata_and_vtt_loaded');

      // The operator controls the device during this window. This wait makes no
      // claim about spoken feedback; the separate human receipt records that.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(minutes: 7)),
      );
      debugPrint('IPEX_QA_TALKBACK_WINDOW_COMPLETE');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
