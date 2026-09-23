import 'dart:convert';

import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/sqlite_learning_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native outbox persists, imports and acknowledges idempotently', (
    tester,
  ) async {
    // Dedicated QA database, never the app outbox or the user's preferences.
    final path = '${await getDatabasesPath()}/outbox_integration_qa.db';
    SqliteLearningOutbox store() => SqliteLearningOutbox(
      open: () => databaseFactory.openDatabase(
        path,
        options: SqliteLearningOutbox.options,
      ),
    );
    var outbox = store();
    const phase = String.fromEnvironment(
      'OUTBOX_QA_PHASE',
      defaultValue: 'roundtrip',
    );
    try {
      final event =
          LearningEvent.activity(
                courseId: 'synthetic-course',
                sessionId: 'synthetic-session',
                sequence: 1,
                activeSeconds: 25,
                occurredAt: DateTime.utc(2026, 9, 23),
              )
              .withCourseContext(
                classId: 'synthetic-cohort',
                courseVersionId: 'synthetic-edition',
              )
              .forLocalOwner(
                userId: 'synthetic-student',
                apiUrl: 'https://staging.example',
              );
      final legacy = jsonEncode([event.toStorageJson()]);
      if (phase != 'verify') {
        await outbox.clear(preserveOwned: false);
        await outbox.importLegacy(legacy);
      }
      if (phase == 'seed') {
        expect((await outbox.pending()).single.eventId, event.eventId);
        return;
      }
      await outbox.close();
      outbox = store();
      final restored = (await outbox.pending()).single;
      expect(restored.toStorageJson(), event.toStorageJson());
      await outbox.acknowledge(event.eventId);
      await outbox.close();
      outbox = store();
      await outbox.importLegacy(legacy);
      expect(await outbox.pending(), isEmpty);
      expect(await outbox.enqueue(event), isFalse);
    } finally {
      await outbox.close();
      if (phase != 'seed') await deleteDatabase(path);
    }
  });
}
