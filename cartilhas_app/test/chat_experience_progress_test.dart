import 'package:cartilhas_app/features/certificates/data/certificate_service.dart';
import 'package:cartilhas_app/features/certificates/models/certificate_record.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:cartilhas_app/features/study_progress/study_progress_repository.dart';
import 'package:cartilhas_app/features/learning_context/learning_context.dart';
import 'package:cartilhas_app/features/learning_context/learning_context_controller.dart';
import 'package:cartilhas_app/features/learning_context/learning_context_repository.dart';
import 'learning_context_test.dart' show contextPayload;
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/chat_experience_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoCertificateService implements CertificateService {
  @override
  Future<CertificateRecord?> findByCourse(String courseId) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineSync implements LearningEventSyncService {
  @override
  String get apiUrl => 'https://staging.example';
  @override
  Future<int> flush() async => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

double progressValue(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value!;

Future<void> openReader(
  WidgetTester tester,
  Cartilha course, {
  LearningContextController? controller,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<CertificateService>.value(value: _NoCertificateService()),
        Provider<LearningEventSyncService>.value(value: _OfflineSync()),
      ],
      child: MaterialApp(
        home: ChatExperienceScreen(
          cartilha: course,
          progressOwnerId: controller?.snapshot?.context.userId,
          learningContextController: controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> advanceReader(WidgetTester tester) async {
  expect(find.text('Continuar').hitTestable(), findsOneWidget);
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    'contextual reader shows shared projection and resumes its own local position',
    (tester) async {
      final controller = LearningContextController(
        FakeLearningContextRepository({
          'class-1': LearningContextSnapshot.fromJson(contextPayload()),
        }),
      );
      addTearDown(controller.dispose);
      await controller.load('class-1');
      final course = Cartilha(
        id: 'course',
        title: 'Context course',
        author: 'TDS',
        classId: 'class-1',
        courseVersionId: 'version-1',
        legacyProgressCompatible: false,
        sections: [
          Section(
            id: 'module',
            title: 'Module',
            messages: [
              Message(type: 'bot', content: 'First contextual message'),
              Message(type: 'bot', content: 'Second contextual message'),
              Message(type: 'bot', content: 'Third contextual message'),
            ],
          ),
        ],
      );
      await openReader(tester, course, controller: controller);
      expect(
        find.textContaining('Progresso confirmado: 12.5%'),
        findsOneWidget,
      );
      await advanceReader(tester);
      expect(find.text('Second contextual message'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await openReader(tester, course, controller: controller);
      expect(
        find.text('Você retomou esta cartilha de onde parou.'),
        findsOneWidget,
      );
      expect(find.text('Second contextual message'), findsOneWidget);
      expect(
        find.textContaining('Progresso confirmado: 12.5%'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'single module progresses only after advancing; Tutor never covers answer or Continue',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final course = Cartilha(
        id: 'reader-progress',
        title: 'Curso de um módulo',
        author: 'Teste',
        sections: [
          Section(
            id: 'module',
            title: 'Módulo',
            messages: [
              Message(type: 'bot', content: 'Primeira mensagem'),
              Message(
                type: 'question',
                content: 'Escolha uma alternativa',
                options: [
                  Option(label: 'Primeira alternativa'),
                  Option(label: 'Segunda alternativa'),
                ],
              ),
              Message(type: 'bot', content: 'Última mensagem'),
            ],
          ),
        ],
      );
      await openReader(tester, course);
      expect(progressValue(tester), 0);
      expect(find.byType(FloatingActionButton), findsNothing);
      final tutor = find.byTooltip('Perguntar ao Tutor de IA');
      expect(
        find.descendant(of: find.byType(AppBar), matching: tutor),
        findsOneWidget,
      );
      expect(tutor.hitTestable(), findsOneWidget);

      await advanceReader(tester);
      expect(progressValue(tester), closeTo(1 / 3, 0.0001));
      final secondAnswer = find.text('Segunda alternativa');
      expect(secondAnswer.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(tutor).overlaps(tester.getRect(secondAnswer)),
        isFalse,
      );
      await tester.tap(secondAnswer);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(progressValue(tester), closeTo(1 / 3, 0.0001));
      expect(
        tester.getRect(tutor).overlaps(tester.getRect(find.text('Continuar'))),
        isFalse,
      );

      await advanceReader(tester);
      expect(progressValue(tester), closeTo(2 / 3, 0.0001));
      expect(find.text('Solicitar certificado'), findsNothing);
      await advanceReader(tester);
      expect(progressValue(tester), 1);
      expect(find.text('Continuar'), findsNothing);
      expect(find.text('Solicitar certificado'), findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNotNull,
      );
      // Only check eligibility: no certificate is issued by this test.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resume in last module weights message counts without implying completion',
    (tester) async {
      final course = Cartilha(
        id: 'resume-reader',
        title: 'Curso',
        author: 'Teste',
        sections: [
          Section(
            id: 'first',
            title: 'Longo',
            messages: [
              Message(type: 'bot', content: 'Um'),
              Message(type: 'bot', content: 'Dois'),
            ],
          ),
          Section(
            id: 'last',
            title: 'Curto',
            messages: [Message(type: 'bot', content: 'Três')],
          ),
        ],
      );
      await const StudyProgressRepository().save(
        StudyProgress(
          courseId: course.id,
          sectionIndex: 1,
          messageIndex: 0,
          questionsAnswered: 0,
          showOptions: false,
          isCompleted: false,
          updatedAt: DateTime.utc(2026, 9, 21),
        ),
      );
      await openReader(tester, course);
      expect(progressValue(tester), closeTo(2 / 3, 0.0001));
      await advanceReader(tester);
      expect(progressValue(tester), 1);
      // Expository courses without quiz questions can also request human review.
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
