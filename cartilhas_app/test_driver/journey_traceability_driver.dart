import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final output = Platform.environment['TDS_JOURNEY_REPORT'];
  final phase = Platform.environment['TDS_JOURNEY_PHASE'];
  final run = Platform.environment['TDS_JOURNEY_RUN'];
  if (output == null ||
      !{'online', 'offline', 'reconnect', 'baseline'}.contains(phase) ||
      run == null) {
    throw StateError('Use the journey host runner');
  }
  await integrationDriver(
    timeout: const Duration(minutes: 5),
    responseDataCallback: (data) async {
      if (data == null ||
          data['run_id'] != run ||
          data['phase'] != phase ||
          data['production_changed'] != false ||
          data['package'] != 'com.tutortds_cartilhas.dev' ||
          data['pid'] is! int ||
          data['assertions'] is! Map) {
        throw StateError('Unexpected traceability run; refuse acceptance');
      }
      await File(output).writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'status': 'passed', 'report': data}),
      );
    },
  );
}
