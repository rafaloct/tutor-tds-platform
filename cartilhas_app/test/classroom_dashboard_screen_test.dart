import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/classrooms/data/classroom_repository.dart';
import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:cartilhas_app/features/classrooms/presentation/classroom_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/certificates/presentation/certificate_requests_screen.dart';

class _FakeGateway
    implements ClassroomGateway, MonitorClassroomGateway, ClassroomRosterGateway {
  _FakeGateway({
    this.role = 'teacher',
    this.userId = 'prof-1',
    this.usageFails = false,
    this.monitor = false,
    this.hasAlerts = true,
  });
  final String role;
  final String userId;
  final bool usageFails;
  final bool monitor;
  final bool hasAlerts;
  int dashboardCalls = 0;
  int monitorExceptionCalls = 0;
  final included = <String>[];

  @override
  Future<EligibleStudentPage> eligibleStudents(
    String classId, {
    String query = '',
    int offset = 0,
  }) async => EligibleStudentPage(
    students: included.isEmpty
        ? const [EligibleStudent(userId: 'candidate-1', name: 'Ana Souza')]
        : const [],
  );

  @override
  Future<void> includeStudent(String classId, String userId) async =>
      included.add(userId);

  static final classroomValue = ClassroomDetails(
    id: 'turma-1',
    programId: 'programa-1',
    courseId: 'agricultura',
    courseVersionId: 'version-a',
    teacherId: 'prof-1',
    name: 'Turma Jalapão',
    startDate: DateTime(2026, 9),
    endDate: DateTime(2026, 12),
    status: 'active',
    studentIds: const [],
    monitorIds: const [],
  );

  @override
  Future<AuthUser> currentUser() async =>
      AuthUser(id: userId, name: 'Pessoa da equipe', role: role);

  @override
  Future<List<ClassroomDetails>> classrooms() async => [classroomValue];

  @override
  Future<ClassroomDetails> classroom(String classId) async => ClassroomDetails(
    id: classroomValue.id,
    programId: classroomValue.programId,
    courseId: classroomValue.courseId,
    teacherId: classroomValue.teacherId,
    name: classroomValue.name,
    startDate: classroomValue.startDate,
    endDate: classroomValue.endDate,
    status: classroomValue.status,
    studentIds: const ['aluno-1'],
    monitorIds: monitor ? [userId] : const [],
  );

  @override
  Future<ClassroomDashboard> dashboard(String classId) async {
    dashboardCalls++;
    return ClassroomDashboard(
      classroom: classroomValue,
      generatedAt: DateTime.utc(2026, 9, 20, 12),
      expectedProgressPercent: 30,
      summary: ClassroomDashboardSummary(
        totalStudents: 1,
        inactiveStudents: hasAlerts ? 1 : 0,
        pendingStudents: 0,
        belowExpectedStudents: hasAlerts ? 1 : 0,
      ),
      students: [
        ClassroomStudent(
          userId: 'aluno-1',
          name: 'Maria da Silva',
          enrollmentId: 'matricula-1',
          status: 'active',
          plannedHours: 40,
          validatedHours: 8,
          progressPercent: 20,
          lastActivityAt: DateTime.utc(2026, 9, 10),
          inactiveDays: 10,
          alerts: hasAlerts
              ? const [ClassroomAlert(code: 'inactive_7_days')]
              : const [],
        ),
      ],
    );
  }

  @override
  Future<MonitorExceptions> monitorExceptions(String classId) async {
    monitorExceptionCalls++;
    final alerts = hasAlerts
        ? const [
            ClassroomAlert(code: 'inactive_7_days'),
            ClassroomAlert(code: 'required_activity_pending'),
            ClassroomAlert(code: 'below_expected_hours'),
          ]
        : const <ClassroomAlert>[];
    return MonitorExceptions(
      generatedAt: DateTime.utc(2026, 9, 20, 12),
      totalStudents: 1,
      attentionStudents: hasAlerts ? 1 : 0,
      students: hasAlerts
          ? [
              MonitorExceptionStudent(
                userId: 'aluno-1',
                name: 'Maria da Silva',
                alerts: alerts,
              ),
            ]
          : const [],
    );
  }

  @override
  Future<UsageSummary> usage(String classId, {int days = 30}) async {
    if (usageFails) throw const ClassroomException('Analytics não autorizado.');
    return UsageSummary(
      periodStart: DateTime.utc(2026, 8, 20),
      periodEnd: DateTime.utc(2026, 9, 20),
      items: [
        UsageItem(
          courseId: 'agricultura',
          eventType: 'feature_used',
          targetId: 'study_hub',
          count: 4,
          uniqueUsers: 1,
          lastOccurredAt: DateTime.utc(2026, 9, 20),
        ),
      ],
    );
  }

  @override
  Future<StudentHours> studentHours({
    required ClassroomDetails classroom,
    required String userId,
  }) async => const StudentHours(
    userId: 'aluno-1',
    programId: 'programa-1',
    courseId: 'agricultura',
    plannedHours: 40,
    validatedHours: 8,
    activeUsage: 9,
  );
}

class _NoSessionAuth implements AuthRepository {
  @override
  Future<String?> localUserId() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TwoClasses extends _FakeGateway {
  _TwoClasses({this.secondIsMonitor = false}) : super(role: 'student');
  final bool secondIsMonitor;
  ClassroomDetails get second => ClassroomDetails(
    id: 'turma-2',
    programId: 'programa-1',
    courseId: 'agricultura',
    courseVersionId: 'version-b',
    teacherId: secondIsMonitor ? 'other' : 'prof-1',
    name: 'Turma B',
    startDate: DateTime(2026, 9),
    endDate: DateTime(2026, 12),
    status: 'active',
    studentIds: const [],
    monitorIds: secondIsMonitor ? const ['prof-1'] : const [],
  );
  @override
  Future<List<ClassroomDetails>> classrooms() async => [
    _FakeGateway.classroomValue,
    second,
  ];
  @override
  Future<ClassroomDetails> classroom(String classId) async =>
      classId == 'turma-2' ? second : _FakeGateway.classroomValue;
  @override
  Future<ClassroomDashboard> dashboard(String classId) async {
    final base = await super.dashboard(classId);
    return ClassroomDashboard(
      classroom: await classroom(classId),
      generatedAt: base.generatedAt,
      expectedProgressPercent: base.expectedProgressPercent,
      summary: base.summary,
      students: base.students,
    );
  }
}

void main() {
  for (final monitor in [false, true]) {
    testWidgets(
      'selected class preserves review context; second monitor=$monitor',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          Provider<AuthRepository>.value(
            value: _NoSessionAuth(),
            child: MaterialApp(
              home: ClassroomDashboardScreen(
                gateway: _TwoClasses(secondIsMonitor: monitor),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Revisar pedidos de certificado'));
        await tester.pumpAndSettle();
        final first = tester.widget<CertificateRequestsScreen>(
          find.byType(CertificateRequestsScreen),
        );
        expect(first.classId, 'turma-1');
        expect(first.courseId, 'agricultura');
        expect(first.courseVersionId, 'version-a');
        expect(first.reviewMode, isTrue);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Turma B').last);
        await tester.pumpAndSettle();
        if (monitor) {
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text('Acompanhamento da turma'),
            ),
            findsOneWidget,
          );
          expect(find.text('Revisar pedidos de certificado'), findsNothing);
        } else {
          await tester.tap(find.text('Revisar pedidos de certificado'));
          await tester.pumpAndSettle();
          final second = tester.widget<CertificateRequestsScreen>(
            find.byType(CertificateRequestsScreen),
          );
          expect(second.classId, 'turma-2');
          expect(second.courseVersionId, 'version-b');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('professor inclui estudante por nome e atualiza painel ao voltar', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await tester.pumpWidget(
      MaterialApp(home: ClassroomDashboardScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Incluir estudantes'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('candidate-1'), findsNothing);
    await tester.tap(find.text('Ana Souza'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Incluir na turma'));
    await tester.tap(find.text('Incluir na turma'));
    await tester.pumpAndSettle();
    expect(gateway.included, ['candidate-1']);
    expect(find.text('Ana Souza foi incluído(a) na turma.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(gateway.dashboardCalls, 2);
  });

  testWidgets('professor vê turma, alertas, carga horária e analytics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: ClassroomDashboardScreen(gateway: _FakeGateway())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Turma Jalapão'), findsWidgets);
    expect(find.text('Maria da Silva'), findsOneWidget);
    expect(find.text('20% • 8 h validadas'), findsOneWidget);
    expect(find.text('Study Hub'), findsOneWidget);

    await tester.tap(find.text('Maria da Silva'));
    await tester.pumpAndSettle();
    expect(find.text('Sem atividade há 7 dias'), findsOneWidget);
    expect(find.text('8 h validadas de 40 h planejadas'), findsOneWidget);
  });

  testWidgets('vínculo de turma prevalece sobre papel global student', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClassroomDashboardScreen(gateway: _FakeGateway(role: 'student')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Turma Jalapão'), findsWidgets);
    expect(find.text('Maria da Silva'), findsOneWidget);
    expect(find.text('Área restrita à equipe'), findsNothing);
  });

  testWidgets('falha isolada de analytics não oculta painel pedagógico', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClassroomDashboardScreen(
          gateway: _FakeGateway(role: 'student', usageFails: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maria da Silva'), findsOneWidget);
    expect(
      find.textContaining('Analytics de recursos temporariamente indisponível'),
      findsOneWidget,
    );
  });

  testWidgets('estudante sem vínculo de equipe não recebe painel', (
    tester,
  ) async {
    final gateway = _FakeGateway(role: 'student', userId: 'aluno-1');
    await tester.pumpWidget(
      MaterialApp(home: ClassroomDashboardScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhuma turma está vinculada à sua conta.'),
      findsOneWidget,
    );
    expect(find.text('Acompanhamento da turma'), findsNothing);
    expect(gateway.dashboardCalls, 0);
  });

  testWidgets('monitor vê somente exceções reais e detalhes autorizados', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeGateway(
      role: 'student',
      userId: 'monitor-1',
      monitor: true,
    );
    await tester.pumpWidget(
      MaterialApp(home: ClassroomDashboardScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acompanhamento da turma'), findsWidgets);
    expect(find.text('Quem precisa de atenção'), findsOneWidget);
    expect(find.text('Precisam de atenção'), findsWidgets);
    expect(find.text('Maria da Silva'), findsOneWidget);
    expect(find.text('Incluir estudantes'), findsNothing);
    expect(find.text('Baseline e mentoria dos estudantes'), findsNothing);
    expect(find.text('Recursos mais usados'), findsNothing);
    expect(find.textContaining('20%'), findsNothing);
    expect(find.textContaining('Matrícula interna'), findsNothing);

    await tester.tap(find.text('Maria da Silva'));
    await tester.pumpAndSettle();
    expect(find.text('Motivos para acompanhar'), findsOneWidget);
    expect(find.text('7 dias ou mais sem atividade'), findsOneWidget);
    expect(find.text('Atividade obrigatória pendente'), findsOneWidget);
    expect(find.text('Carga horária abaixo do esperado'), findsOneWidget);
    expect(find.textContaining('validadas de'), findsNothing);
    expect(find.textContaining('Baseline'), findsNothing);
    expect(find.textContaining('Mentorias'), findsNothing);
    expect(gateway.dashboardCalls, 0);
    expect(gateway.monitorExceptionCalls, 1);
  });

  testWidgets('monitor sem alertas recebe estado normal vazio', (tester) async {
    final gateway = _FakeGateway(
      role: 'student',
      userId: 'monitor-1',
      monitor: true,
      hasAlerts: false,
    );
    await tester.pumpWidget(
      MaterialApp(home: ClassroomDashboardScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tudo certo'), findsOneWidget);
    expect(find.text('Tudo certo por enquanto'), findsOneWidget);
    expect(find.text('Maria da Silva'), findsNothing);
    expect(gateway.dashboardCalls, 0);
    expect(gateway.monitorExceptionCalls, 1);
  });

  testWidgets('monitor suporta escala de fonte ampliada sem overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final gateway = _FakeGateway(
      role: 'student',
      userId: 'monitor-1',
      monitor: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ClassroomDashboardScreen(gateway: gateway),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acompanhamento da turma'), findsWidgets);
    expect(
      tester.getSemantics(find.text('Acompanhamento da turma').first).label,
      contains('Acompanhamento da turma'),
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cockpit do professor suporta fonte 200% em landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ClassroomDashboardScreen(gateway: _FakeGateway()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acompanhamento de turma'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Acompanhamento de turma')).label,
      contains('Acompanhamento de turma'),
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
