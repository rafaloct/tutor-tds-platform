import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runId = String.fromEnvironment('PREBUILT_QA_RUN_ID');
const _namespace = 'tds.qa.prebuilt_apk_smoke.v1.';

/// QA entrypoint only: no CartilhasApp, HTTP, credentials or outbox access.
/// The same compiled test chooses its phase from its own durable checkpoint.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'one APK preserves a QA checkpoint across processes',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      expect(const bool.fromEnvironment('dart.vm.product'), isFalse);
      expect(const String.fromEnvironment('TUTOR_ENVIRONMENT'), 'staging');
      expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(_runId), isTrue);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: Text('Prebuilt APK QA smoke')),
        ),
      );
      expect(find.text('Prebuilt APK QA smoke'), findsOneWidget);

      final preferences = await SharedPreferences.getInstance();
      final otherValues = <String, Object?>{
        for (final key in preferences.getKeys())
          if (!key.startsWith(_namespace)) key: preferences.get(key),
      };
      final key = '$_namespace$_runId';
      final encoded = preferences.getString(key);
      late final String phase;
      late final Map<String, dynamic> checkpoint;
      if (encoded == null) {
        phase = 'seed';
        checkpoint = {
          'run_id': _runId,
          'completed_phase': phase,
          'first_pid': pid,
          'nonce': List<int>.generate(
            16,
            (_) => Random.secure().nextInt(256),
          ).map((value) => value.toRadixString(16).padLeft(2, '0')).join(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
      } else {
        phase = 'verify';
        checkpoint = jsonDecode(encoded) as Map<String, dynamic>;
        expect(checkpoint['run_id'], _runId);
        expect(checkpoint['completed_phase'], 'seed');
        expect(checkpoint['first_pid'], isA<int>());
        expect(checkpoint['first_pid'], isNot(pid));
        expect(checkpoint['nonce'], matches(RegExp(r'^[a-f0-9]{32}$')));
        expect(checkpoint['created_at'], isA<String>());
        checkpoint['completed_phase'] = phase;
      }
      expect(await preferences.setString(key, jsonEncode(checkpoint)), isTrue);
      await preferences.reload();
      expect(jsonDecode(preferences.getString(key)!), checkpoint);
      expect(
        <String, Object?>{
          for (final existingKey in preferences.getKeys())
            if (!existingKey.startsWith(_namespace))
              existingKey: preferences.get(existingKey),
        },
        otherValues,
        reason: 'The smoke test may change only its own QA namespace.',
      );
      binding.reportData = {
        'run_id': _runId,
        'phase': phase,
        'pid': pid,
        'first_pid': checkpoint['first_pid'],
        'nonce': checkpoint['nonce'],
        'created_at': checkpoint['created_at'],
        'other_preferences_unchanged': true,
        'production_app_started': false,
        'http_used': false,
      };
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
