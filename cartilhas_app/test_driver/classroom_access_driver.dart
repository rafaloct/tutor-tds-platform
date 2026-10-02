import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final output = Platform.environment['TDS_ACCESS_REPORT'];
  final phase = Platform.environment['TDS_ACCESS_PHASE'];
  final run = Platform.environment['TDS_ACCESS_RUN'];
  if (output == null || run == null || phase == null) {
    throw StateError('Use access QA runner');
  }
  await integrationDriver(
    timeout: const Duration(minutes: 11),
    responseDataCallback: (data) async {
      if (data == null ||
          data['run_id'] != run ||
          data['phase'] != phase ||
          data['production_changed'] != false ||
          data['checks'] is! Map ||
          data['pid'] is! int) {
        throw StateError('Unexpected physical access report');
      }
      await File(output).writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'status': 'passed', 'report': data}),
      );
    },
  );
}
