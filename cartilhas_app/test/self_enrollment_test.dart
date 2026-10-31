import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/certificates/data/certificate_service.dart';
import 'package:cartilhas_app/features/certificates/models/certificate_record.dart';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:cartilhas_app/features/classrooms/data/self_enrollment_repository.dart';
import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:cartilhas_app/features/classrooms/presentation/learner_classrooms_screen.dart';
import 'package:cartilhas_app/features/learning_context/learning_context.dart';
import 'package:cartilhas_app/features/learning_context/learning_context_repository.dart';
import 'package:cartilhas_app/features/learning_events/learning_event_sync_service.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/chat_experience_screen.dart';
import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> v2Payload({
  String cohort = 'class-open',
  String owner = 'student',
  String courseId = 'course',
  String version = 'version-1',
}) => {
  'context': {
    'user_id': owner,
    'organization_id': 'org',
    'program_id': 'program',
    'cohort_id': cohort,
    'membership_id': 'membership-$cohort',
    'role': 'student',
    'course_id': courseId,
    'course_version_id': version,
    'enrollment_id': 'context-enroll',
    'legacy_enrollment_id': 'enrollment',
    'permissions': ['content.read', 'progress.read', 'activity.record'],
  },
  'progress': {
    'user_id': owner,
    'enrollment_id': 'enrollment',
    'context_enrollment_id': 'context-enroll',
    'progress_percent': 0,
    'validated_hours': 0,
  },
  'resolved_at': '2026-09-23T12:00:00Z',
  'contract_version': 'cohort-enrollment-v2',
};

const openItem = OpenClassItem(
  id: 'class-open',
  programId: 'program',
  courseId: 'course',
  courseTitle: 'Curso Aberto',
  name: 'Turma Aberta — Curso',
  status: 'active',
  viewerEnrolled: false,
  courseVersionId: 'version-1',
);

class FakeSelfEnroll implements SelfEnrollmentGateway {
  final calls = <String>[];
  List<OpenClassItem> open = const [openItem];
  bool failEnroll = false;
  bool failOpen = false;

  @override
  Future<LearningContextSnapshot> selfEnroll(String courseId) async {
    calls.add(courseId);
    if (failEnroll) {
      throw const LearningContextException('Falha na matrícula.');
    }
    return LearningContextSnapshot.fromJson(v2Payload(courseId: courseId));
  }

  @override
  Future<List<OpenClassItem>> openClasses() async {
    if (failOpen) throw const LearningContextException('Sem conexão.');
    return open;
  }
}

class FakeLearnerGateway implements LearnerClassroomGateway {
  @override
  Future<AuthUser> currentUser() async =>
      const AuthUser(id: 'student', name: 'Aluno', role: 'student');
  @override
  Future<List<ClassroomDetails>> learnerClassrooms() async => const [];
  @override
  Future<Cartilha> course(String classId) async => Cartilha(
    id: 'course',
    title: 'Edição fixada',
    author: 'TDS',
    sections: [
      Section(
        id: 's1',
        title: 'Módulo',
        messages: [Message(type: 'bot', content: 'Conteúdo')],
      ),
    ],
    courseVersionId: 'version-1',
    classId: classId,
    legacyProgressCompatible: false,
  );
}

class _NoCertificateService implements CertificateService {
  @override
  Future<CertificateRecord?> findByCourse(String courseId) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineSync implements LearningEventSyncService {
  @override
  String get apiUrl => 'https://test.example';
  @override
  AuthRepository get authRepository => FakeAuth();
  @override
  Future<int> flush() async => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth extends AuthRepository {
  FakeAuth({this.session = true}) : super(apiUrl: 'https://test.example');
  bool session;
  @override
  Future<bool> hasSession() async => session;
  @override
  Future<String?> localUserId() async => session ? 'student' : null;
  @override
  Future<http.Response> authorized(
    Future<http.Response> Function(String) request,
  ) => request('test-token');
}

Cartilha publicCourse() => Cartilha(
  id: 'course',
  title: 'Curso Público',
  author: 'TDS',
  sections: [
    Section(
      id: 's1',
      title: 'Módulo',
      messages: [Message(type: 'bot', content: 'Conteúdo')],
    ),
  ],
  courseVersionId: 'version-1',
);

Widget homeSubject({
  FakeSelfEnroll? selfEnroll,
  LearningContextRepository? contexts,
  LearnerClassroomGateway? gateway,
  AuthRepository? auth,
}) {
  final screen = HomeScreen(
    courseLoader: () async => [publicCourse()],
    selfEnrollmentGateway: selfEnroll,
    learningContextRepository: contexts,
    classroomGateway: gateway,
  );
  return MultiProvider(
    providers: [
      Provider<CertificateService>.value(value: _NoCertificateService()),
      Provider<LearningEventSyncService>.value(value: _OfflineSync()),
      if (auth != null) Provider<AuthRepository>.value(value: auth),
    ],
    child: MaterialApp(home: screen),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LearnerClassroomsScreen', () {
    testWidgets('seção de cursos abertos fica oculta sem gateway', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: LearnerClassroomsScreen(gateway: FakeLearnerGateway())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cursos abertos'), findsNothing);
    });

    testWidgets('toque na turma aberta matricula e abre edição fixada', (
      tester,
    ) async {
      final selfEnroll = FakeSelfEnroll();
      Cartilha? opened;
      String? owner;
      await tester.pumpWidget(
        MaterialApp(
          home: LearnerClassroomsScreen(
            gateway: FakeLearnerGateway(),
            selfEnrollmentGateway: selfEnroll,
            contextRepository: FakeLearningContextRepository({
              'class-open': LearningContextSnapshot.fromJson(v2Payload()),
            }),
            onOpenCourse: (course, userId) {
              opened = course;
              owner = userId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cursos abertos'), findsOneWidget);
      expect(find.text('Curso Aberto'), findsOneWidget);
      await tester.tap(find.text('Curso Aberto'));
      await tester.pumpAndSettle();
      expect(selfEnroll.calls, ['course']);
      expect(opened?.classId, 'class-open');
      expect(opened?.courseVersionId, 'version-1');
      expect(owner, 'student');
    });

    testWidgets('falha na matrícula mostra erro e não abre conteúdo', (
      tester,
    ) async {
      final selfEnroll = FakeSelfEnroll()..failEnroll = true;
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: LearnerClassroomsScreen(
            gateway: FakeLearnerGateway(),
            selfEnrollmentGateway: selfEnroll,
            contextRepository: FakeLearningContextRepository({
              'class-open': LearningContextSnapshot.fromJson(v2Payload()),
            }),
            onOpenCourse: (_, _) => opened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Curso Aberto'));
      await tester.pumpAndSettle();
      expect(selfEnroll.calls, ['course']);
      expect(opened, isFalse);
      expect(
        find.textContaining('Não foi possível concluir sua matrícula'),
        findsOneWidget,
      );
    });

    testWidgets('falha ao listar abertas não esconde turmas do aluno', (
      tester,
    ) async {
      final selfEnroll = FakeSelfEnroll()..failOpen = true;
      await tester.pumpWidget(
        MaterialApp(
          home: LearnerClassroomsScreen(
            gateway: _EnrolledGateway(),
            selfEnrollmentGateway: selfEnroll,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Minha turma'), findsOneWidget);
      expect(find.text('Cursos abertos'), findsNothing);
    });
  });

  group('HomeScreen', () {
    testWidgets('sem gateway o toque abre o curso público direto', (
      tester,
    ) async {
      await tester.pumpWidget(homeSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Curso Público'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatExperienceScreen), findsOneWidget);
    });

    testWidgets('sem sessão oferece conta mas preserva acesso público', (
      tester,
    ) async {
      final selfEnroll = FakeSelfEnroll();
      await tester.pumpWidget(
        homeSubject(
          selfEnroll: selfEnroll,
          gateway: FakeLearnerGateway(),
          auth: FakeAuth(session: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Curso Público'));
      await tester.pumpAndSettle();
      expect(find.text('Criar sua matrícula'), findsOneWidget);
      await tester.tap(find.text('Continuar sem conta'));
      await tester.pumpAndSettle();
      expect(selfEnroll.calls, isEmpty);
      expect(find.byType(ChatExperienceScreen), findsOneWidget);
    });

    testWidgets('com sessão o primeiro toque matricula e abre edição', (
      tester,
    ) async {
      final selfEnroll = FakeSelfEnroll();
      await tester.pumpWidget(
        homeSubject(
          selfEnroll: selfEnroll,
          gateway: FakeLearnerGateway(),
          contexts: FakeLearningContextRepository({
            'class-open': LearningContextSnapshot.fromJson(v2Payload()),
          }),
          auth: FakeAuth(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Curso Público'));
      await tester.pumpAndSettle();
      expect(selfEnroll.calls, ['course']);
      expect(find.byType(ChatExperienceScreen), findsOneWidget);
      expect(find.text('Edição fixada'), findsOneWidget);
    });

    testWidgets('falha na matrícula mantém acesso público com aviso', (
      tester,
    ) async {
      final selfEnroll = FakeSelfEnroll()..failEnroll = true;
      await tester.pumpWidget(
        homeSubject(
          selfEnroll: selfEnroll,
          gateway: FakeLearnerGateway(),
          auth: FakeAuth(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Curso Público'));
      await tester.pumpAndSettle();
      expect(selfEnroll.calls, ['course']);
      expect(find.byType(ChatExperienceScreen), findsOneWidget);
      expect(
        find.textContaining('Não foi possível criar sua matrícula'),
        findsOneWidget,
      );
    });
  });
}

class _EnrolledGateway extends FakeLearnerGateway {
  @override
  Future<List<ClassroomDetails>> learnerClassrooms() async => [
    ClassroomDetails(
      id: 'class-1',
      programId: 'program',
      courseId: 'course',
      teacherId: 'teacher',
      name: 'Minha turma',
      startDate: DateTime(2026),
      endDate: DateTime(2027),
      status: 'active',
      studentIds: const [],
      monitorIds: const [],
    ),
  ];
}
