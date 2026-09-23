import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final output = Platform.environment['TDS_QA_SMOKE_REPORT_PATH'];
  final runId = Platform.environment['TDS_QA_SMOKE_RUN_ID'];
  final phase = Platform.environment['TDS_QA_SMOKE_EXPECTED_PHASE'];
  if (output == null || runId == null || !{'seed', 'verify'}.contains(phase)) {
    throw StateError('Use tooling/test_prebuilt_apk_smoke.ps1.');
  }
  await integrationDriver(
    timeout: const Duration(minutes: 3),
    responseDataCallback: (data) async {
      if (data == null || data['run_id'] != runId || data['phase'] != phase) {
        throw StateError(
          'Unexpected APK or smoke checkpoint; refusing success.',
        );
      }
      await File(output).writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'status': 'passed', 'report': data}),
      );
    },
  );
}
