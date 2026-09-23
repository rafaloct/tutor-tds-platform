import 'package:cartilhas_app/features/learning_events/learning_delivery_status.dart';
import 'package:cartilhas_app/features/learning_events/learning_outbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'learning_delivery_controller_test.dart';

void main() {
  testWidgets('pending uses committed study records, not official progress', (
    tester,
  ) async {
    final f = DeliveryFixture();
    addTearDown(f.dispose);
    f.queue.status = const LearningDeliverySnapshot(pendingCount: 2);
    await f.controller.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const Text('Progresso confirmado: 25%'),
              LearningDeliveryStatus(controller: f.controller),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('learning-delivery-pending')), findsOneWidget);
    expect(find.textContaining('2 registros do estudo'), findsOneWidget);
    expect(find.text('Progresso confirmado: 25%'), findsOneWidget);
    f.queue.status = const LearningDeliverySnapshot();
    f.queue.changed.emit();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('learning-delivery-pending')), findsNothing);
    expect(find.text('Progresso confirmado: 25%'), findsOneWidget);
  });

  testWidgets(
    'storage error is honest, retry preserves evidence, narrow large text fits',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      f.queue.enqueueFailure = const OutboxStorageException('enqueue');
      final event = deliveryEvent();
      await f.controller.record(event);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              children: [LearningDeliveryStatus(controller: f.controller)],
            ),
          ),
        ),
      );
      expect(
        find.byKey(const Key('learning-delivery-storage-error')),
        findsOneWidget,
      );
      expect(find.text('Atividade ainda não salva'), findsOneWidget);
      expect(find.text('Atividades salvas neste aparelho'), findsNothing);
      expect(tester.takeException(), isNull);
      f.queue.enqueueFailure = null;
      await tester.ensureVisible(
        find.byKey(const Key('learning-delivery-retry')),
      );
      await tester.tap(find.byKey(const Key('learning-delivery-retry')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('learning-delivery-storage-error')),
        findsNothing,
      );
      expect(f.queue.writes.last.toStorageJson(), event.toStorageJson());
      expect(
        find.byKey(const Key('learning-delivery-pending')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'blocked and failed-read states are distinct from an empty queue',
    (tester) async {
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      f.queue.status = const LearningDeliverySnapshot(
        blockedCount: 1,
        blockedEvents: [
          BlockedLearningEvent(eventId: 'blocked', lastStatus: 422),
        ],
      );
      await f.controller.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [LearningDeliveryStatus(controller: f.controller)],
            ),
          ),
        ),
      );
      expect(
        find.byKey(const Key('learning-delivery-blocked')),
        findsOneWidget,
      );
      expect(find.text('Tentar os mesmos envios'), findsOneWidget);
      f.queue.readFailure = const OutboxDataException('persisted');
      await f.controller.refresh();
      await tester.pump();
      expect(find.byKey(const Key('learning-delivery-error')), findsOneWidget);
      expect(find.text('Não foi possível conferir os envios'), findsOneWidget);
    },
  );
}
