import 'package:cartilhas_app/features/certificates/data/certificate_service.dart';
import 'package:cartilhas_app/features/certificates/models/certificate_record.dart';
import 'package:cartilhas_app/features/learning_context/learning_context.dart';
import 'package:cartilhas_app/features/learning_context/learning_context_controller.dart';
import 'package:cartilhas_app/features/learning_context/learning_context_repository.dart';
import 'package:cartilhas_app/features/learning_events/learning_event.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:cartilhas_app/features/learning_events/learning_outbox.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/chat_experience_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'learning_delivery_controller_test.dart';

class _Certificates implements CertificateService {
  @override
  Future<CertificateRecord?> findByCourse(String courseId) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _reader(
  WidgetTester tester,
  DeliveryFixture f, {
  bool singleMessage = false,
  double textScale = 1,
}) async {
  final contextController = LearningContextController(
    FakeLearningContextRepository({
      'cohort': LearningContextSnapshot(
        context: const LearningContext(
          userId: 'student',
          organizationId: 'organization',
          programId: 'program',
          cohortId: 'cohort',
          membershipId: 'membership',
          role: 'student',
          courseId: 'course',
          courseVersionId: 'edition',
          enrollmentId: 'enrollment',
          legacyEnrollmentId: 'legacy-enrollment',
          permissions: {'content.read', 'activity.record', 'progress.read'},
        ),
        progressPercent: 25,
        validatedHours: 1,
        resolvedAt: DateTime.utc(2026, 9, 23),
        contractVersion: 'cohort-enrollment-v2',
      ),
    }),
  );
  addTearDown(contextController.dispose);
  await contextController.load('cohort');
  final course = Cartilha(
    id: 'course',
    title: 'Contextual course',
    author: 'TDS',
    classId: 'cohort',
    courseVersionId: 'edition',
    legacyProgressCompatible: false,
    sections: [
      Section(
        id: 'module',
        title: 'Module',
        messages: [
          Message(type: 'bot', content: 'First message'),
          if (!singleMessage) ...[
            Message(type: 'bot', content: 'Second message'),
            Message(type: 'bot', content: 'Third message'),
          ],
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<CertificateService>.value(value: _Certificates()),
        Provider<LearningEventSyncService>.value(value: f.sync),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ChatExperienceScreen(
          cartilha: course,
          progressOwnerId: 'student',
          learningContextController: contextController,
          deliveryController: f.controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  testWidgets(
    'unsaved lesson start blocks action/back until the exact event commits',
    (tester) async {
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      f.queue.enqueueFailure = const OutboxStorageException('enqueue');
      await _reader(tester, f);
      final started = f.queue.writes.single;
      expect(started.type, LearningEventType.lessonStarted);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Continuar'),
            )
            .onPressed,
        isNull,
      );
      final pop = tester.widget<PopScope>(
        find.byWidgetPredicate((widget) => widget is PopScope),
      );
      expect(pop.canPop, isFalse);
      expect(find.text('Atividade ainda não salva'), findsOneWidget);
      f.queue.enqueueFailure = null;
      await f.controller.retrySave();
      await tester.pumpAndSettle();
      expect(f.queue.writes.last.toStorageJson(), started.toStorageJson());
      expect(
        tester
            .widget<PopScope>(
              find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .canPop,
        isTrue,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Continuar'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Second message'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completion intent runs once after retry without regenerating evidence',
    (tester) async {
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      await _reader(tester, f, singleMessage: true);
      f.queue.enqueueFailure = const OutboxStorageException('enqueue');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      final completion = f.queue.writes.last;
      expect(completion.type, LearningEventType.lessonCompleted);
      expect(find.text('Solicitar certificado'), findsNothing);
      expect(f.controller.hasUnsavedEvent, isTrue);
      f.queue.enqueueFailure = null;
      await f.controller.retrySave();
      await tester.pumpAndSettle();
      expect(find.text('Solicitar certificado'), findsOneWidget);
      final attempts = f.queue.writes
          .where((event) => event.type == LearningEventType.lessonCompleted)
          .toList();
      expect(attempts, hasLength(2));
      expect(attempts.last.toStorageJson(), completion.toStorageJson());
      f.queue.changed.emit();
      await tester.pumpAndSettle();
      expect(
        f.queue.writes.where(
          (event) => event.type == LearningEventType.lessonCompleted,
        ),
        hasLength(2),
      );
      expect(find.textContaining('🎉 Parabéns!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initial command resumes after a projection failure without another session event',
    (tester) async {
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      f.queue.readFailure = const OutboxDataException('persisted');
      await f.controller.refresh();
      await _reader(tester, f);
      expect(f.queue.writes, isEmpty);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Continuar'),
            )
            .onPressed,
        isNull,
      );
      f.queue.readFailure = null;
      await f.controller.refresh();
      await tester.pumpAndSettle();
      expect(f.queue.writes, hasLength(1));
      expect(f.queue.writes.single.type, LearningEventType.lessonStarted);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Continuar'),
            )
            .onPressed,
        isNotNull,
      );
      f.queue.changed.emit();
      await tester.pumpAndSettle();
      expect(f.queue.writes, hasLength(1));
    },
  );

  testWidgets(
    'committed completion waits safely for projection recovery then applies once',
    (tester) async {
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      await _reader(tester, f, singleMessage: true);
      f.queue.readFailure = const OutboxStorageException('deliveryStatus');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(f.queue.writes.last.type, LearningEventType.lessonCompleted);
      expect(f.controller.hasUnsavedEvent, isFalse);
      expect(find.text('Solicitar certificado'), findsNothing);
      expect(
        tester
            .widget<PopScope>(
              find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .canPop,
        isFalse,
      );
      f.queue.readFailure = null;
      await f.controller.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Solicitar certificado'), findsOneWidget);
      expect(
        tester
            .widget<PopScope>(
              find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .canPop,
        isTrue,
      );
      expect(
        f.queue.writes.where(
          (event) => event.type == LearningEventType.lessonCompleted,
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'full reader keeps storage recovery reachable at 320px and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = DeliveryFixture();
      addTearDown(f.dispose);
      f.queue.enqueueFailure = const OutboxStorageException('enqueue');
      await _reader(tester, f, textScale: 2);
      await tester.ensureVisible(
        find.byKey(const Key('learning-delivery-retry')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('learning-delivery-retry')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
