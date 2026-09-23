import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final output = Platform.environment['TDS_QA_DYNAMIC_REPORT_PATH'];
  final runId = Platform.environment['TDS_QA_DYNAMIC_RUN_ID'];
  final phase = Platform.environment['TDS_QA_DYNAMIC_EXPECTED_PHASE'];
  const phases = {
    'author_v1',
    'publisher_v1',
    'learner_v1',
    'author_v2',
    'publisher_v2',
    'learner_after_v2',
    'learner_offline',
    'learner_reconnect',
  };
  if (output == null || runId == null || !phases.contains(phase)) {
    throw StateError('Use the approved dynamic-learning host runner.');
  }
  await integrationDriver(
    timeout: const Duration(minutes: 16),
    responseDataCallback: (data) async {
      if (data == null ||
          data['run_id'] != runId ||
          data['phase'] != phase ||
          data['completed_phase'] != phase ||
          data['pid'] is! int ||
          data['course_id'] != 'qa-dynamic-course-$runId' ||
          data['program_id'] != 'qa-dynamic-program' ||
          data['checkpoint'] is! Map ||
          (data['checkpoint'] as Map)['completed_phase'] != phase ||
          (data['checkpoint'] as Map)['run_id'] != runId ||
          (data['checkpoint'] as Map)['course_id'] != data['course_id'] ||
          (data['checkpoint'] as Map)['program_id'] != data['program_id']) {
        throw StateError(
          'Unexpected APK, phase or checkpoint; refuse success.',
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
