import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:cartilhas_app/features/evidence/data/evidence_repository.dart';
import 'package:cartilhas_app/features/evidence/models/evidence_models.dart';
import 'package:cartilhas_app/features/evidence/presentation/evidence_checkin_screen.dart';
import 'package:cartilhas_app/features/evidence/presentation/evidence_staff_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _FakeEvidenceGateway implements EvidenceGateway {
  _FakeEvidenceGateway({this.recoverOpen = false});

  final bool recoverOpen;
  int tokenVersion = 1;
  String? lastIdempotencyKey;
  bool reviewed = false;

  @override
  Future<EvidenceSession?> openSession(String classId) async =>
      recoverOpen ? _session(classId, 3, includeToken: false) : null;

  @override
  Future<EvidenceSessionPage> listSessions(
    String classId, {
    String? status,
    int limit = 50,
    int offset = 0,
  }) async => EvidenceSessionPage(
    sessions: const [],
    total: 0,
    limit: limit,
    offset: offset,
  );

  @override
  Future<EvidenceSession?> session(String classId, String sessionId) async =>
      _session(classId, 3, includeToken: false);

  @override
  Future<EvidenceSession> createSession({
    required String classId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async => _session(classId, tokenVersion);

  @override
  Future<EvidenceSession> rotateToken(String classId, String sessionId) async =>
      _session(classId, ++tokenVersion);

  @override
  Future<EvidenceCheckin> checkin({
    required String classId,
    required String sessionId,
    required String kind,
    required String idempotencyKey,
    required String token,
  }) async {
    lastIdempotencyKey = idempotencyKey;
    return EvidenceCheckin(
      id: 'checkin-1',
      sessionId: sessionId,
      userId: 'student-me',
      kind: kind,
      occurredAt: DateTime.utc(2026, 9, 20, 14),
      method: 'qr',
      evidenceId: 'evidence-student',
    );
  }

  @override
  Future<List<EvidenceExceptionItem>> exceptions(String classId) async =>
      reviewed
      ? const []
      : const [
          EvidenceExceptionItem(
            code: 'evidence_needs_review',
            evidenceId: 'evidence-1',
            userId: 'student-1',
          ),
        ];

  @override
  Future<EvidenceReviewResult> review({
    required String classId,
    required String evidenceId,
    required String decision,
    required String reasonCode,
  }) async {
    reviewed = true;
    return EvidenceReviewResult(
      evidenceId: evidenceId,
      decision: decision,
      reasonCode: reasonCode,
      decidedAt: DateTime.utc(2026, 9, 20),
    );
  }

  @override
  Future<EvidenceReport> closeSession({
    required String classId,
    required String sessionId,
    bool confirmPending = false,
  }) async => EvidenceReport(
    id: 'report-1',
    classId: classId,
    sessionId: sessionId,
    generatedAt: DateTime.utc(2026, 9, 20),
    reportDigest: 'digest',
    summary: const {'checkin_count': 1, 'pending_evidence_ids': []},
  );

  @override
  Future<EvidenceImportRecord> createImport({
    required String classId,
    required String sourceType,
    required String sourceDigest,
    required String idempotencyKey,
    required DateTime retentionUntil,
    required List<EvidenceImportItemDraft> items,
  }) => throw UnimplementedError();

  @override
  Future<EvidenceImportRecord> getImport(String classId, String importId) =>
      throw UnimplementedError();

  @override
  Future<EvidenceReport> report(String classId, String reportId) =>
      throw UnimplementedError();

  EvidenceSession _session(
    String classId,
    int version, {
    bool includeToken = true,
  }) => EvidenceSession(
    id: 'session-1',
    classId: classId,
    startsAt: DateTime.utc(2026, 9, 20, 13),
    endsAt: DateTime.utc(2026, 9, 20, 15),
    status: 'open',
    tokenExpiresAt: DateTime.utc(2026, 9, 20, 14, 10),
    tokenVersion: version,
    checkinToken: includeToken ? 'token-$version' : null,
  );
}

void main() {
  testWidgets('aluno registra somente a própria presença por código', (
    tester,
  ) async {
    final gateway = _FakeEvidenceGateway();
    await tester.pumpWidget(
      MaterialApp(home: EvidenceCheckinScreen(gateway: gateway)),
    );

    await tester.enterText(
      find.byType(TextFormField),
      'tutortds://checkin?class_id=class-1&session_id=session-1&token=token-1',
    );
    await tester.tap(find.text('Confirmar entrada'));
    await tester.pumpAndSettle();

    expect(find.text('Entrada confirmada'), findsOneWidget);
    expect(find.textContaining('evidence-student'), findsOneWidget);
    expect(find.textContaining('lista da turma'), findsOneWidget);
    expect(gateway.lastIdempotencyKey, startsWith('mobile:'));
    expect(find.text('student-1'), findsNothing);
  });

  testWidgets('equipe abre sessão, rotaciona QR e revisa exceção', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeEvidenceGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: EvidenceStaffScreen(
          classroom: ClassroomDetails(
            id: 'class-1',
            programId: 'program-1',
            courseId: 'course-1',
            teacherId: 'teacher-1',
            name: 'Turma Jalapão',
            startDate: DateTime.utc(2026, 9),
            endDate: DateTime.utc(2026, 12),
            status: 'active',
            studentIds: const [],
            monitorIds: const [],
          ),
          gateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evidência precisa de revisão'), findsOneWidget);
    await tester.tap(find.text('Abrir sessão agora'));
    await tester.pumpAndSettle();
    expect(find.textContaining('token v1'), findsOneWidget);
    expect(find.text('Rotacionar QR'), findsOneWidget);

    await tester.tap(find.text('Rotacionar QR'));
    await tester.pumpAndSettle();
    expect(find.textContaining('token v2'), findsOneWidget);

    await tester.tap(find.byTooltip('Decidir sobre evidência'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceitar com motivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verificada manualmente'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nenhuma evidência pendente visível para sua conta.'),
      findsOneWidget,
    );
  });

  testWidgets('equipe recupera sessão aberta sem reexibir token', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeEvidenceGateway(recoverOpen: true);
    await tester.pumpWidget(
      MaterialApp(
        home: EvidenceStaffScreen(
          classroom: ClassroomDetails(
            id: 'class-1',
            programId: 'program-1',
            courseId: 'course-1',
            teacherId: 'teacher-1',
            name: 'Turma Jalapão',
            startDate: DateTime.utc(2026, 9),
            endDate: DateTime.utc(2026, 12),
            status: 'active',
            studentIds: const [],
            monitorIds: const [],
          ),
          gateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('token v3'), findsOneWidget);
    expect(
      find.textContaining('token anterior não é reexibido'),
      findsOneWidget,
    );
    expect(find.text('Rotacionar QR'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);

    await tester.tap(find.text('Rotacionar QR'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('check-in preserva formulário e semântica com fonte 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
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
        home: EvidenceCheckinScreen(gateway: _FakeEvidenceGateway()),
      ),
    );
    await tester.pump();

    expect(find.text('Registrar presença'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Registrar presença')).label,
      contains('Registrar presença'),
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cockpit de evidências suporta fonte 200% em landscape', (
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
        home: EvidenceStaffScreen(
          classroom: ClassroomDetails(
            id: 'class-1',
            programId: 'program-1',
            courseId: 'course-1',
            teacherId: 'teacher-1',
            name: 'Turma Jalapão',
            startDate: DateTime.utc(2026, 9),
            endDate: DateTime.utc(2026, 12),
            status: 'active',
            studentIds: const [],
            monitorIds: const [],
          ),
          gateway: _FakeEvidenceGateway(recoverOpen: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Presença e evidências'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Presença e evidências')).label,
      contains('Presença e evidências'),
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
