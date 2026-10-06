import 'package:cartilhas_app/features/evidence/data/checkin_draft_store.dart';
import 'package:cartilhas_app/features/classrooms/models/classroom_models.dart';
import 'package:cartilhas_app/features/evidence/data/evidence_repository.dart';
import 'package:cartilhas_app/features/evidence/models/evidence_models.dart';
import 'package:cartilhas_app/features/evidence/presentation/evidence_checkin_screen.dart';
import 'package:cartilhas_app/features/evidence/presentation/evidence_staff_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEvidenceGateway implements EvidenceGateway {
  @override
  Future<SessionPresencePage> presence(
    String classId,
    String sessionId, {
    int offset = 0,
  }) async => const SessionPresencePage(
    items: [],
    total: 0,
    offset: 0,
    limit: 50,
    sessionStatus: 'open',
  );
  @override
  Future<SessionPresence> decidePresence({
    required String classId,
    required String sessionId,
    required String userId,
    required String status,
    required int expectedRevision,
    required String reason,
    required String idempotencyKey,
  }) => throw UnimplementedError();
  _FakeEvidenceGateway({this.recoverOpen = false});

  final bool recoverOpen;
  int tokenVersion = 1;
  String? lastIdempotencyKey;
  String? lastToken;
  String? lastCode;
  String? lastCodeKind;
  final List<String> idempotencyKeys = [];
  bool failCheckinWithNetwork = false;
  bool reviewed = false;
  Duration sessionValidity = const Duration(minutes: 10);
  Duration postRotationValidity = const Duration(minutes: 10);

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
      _session(
        classId,
        ++tokenVersion,
        tokenExpiresAt: DateTime.now().add(postRotationValidity),
      );

  @override
  Future<EvidenceCheckin> checkin({
    required String classId,
    required String sessionId,
    required String kind,
    required String idempotencyKey,
    required String token,
  }) async {
    lastIdempotencyKey = idempotencyKey;
    lastToken = token;
    idempotencyKeys.add(idempotencyKey);
    if (failCheckinWithNetwork) {
      throw const EvidenceApiException(
        'Sem conexão com o registro de evidências. Nenhum dado foi enviado.',
        isNetworkFailure: true,
      );
    }
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
  Future<EvidenceCheckin> checkinByCode({
    required String code,
    required String kind,
    required String idempotencyKey,
  }) async {
    lastIdempotencyKey = idempotencyKey;
    idempotencyKeys.add(idempotencyKey);
    lastCode = code;
    lastCodeKind = kind;
    if (failCheckinWithNetwork) {
      throw const EvidenceApiException(
        'Sem conexão com o registro de evidências. Nenhum dado foi enviado.',
        isNetworkFailure: true,
      );
    }
    return EvidenceCheckin(
      id: 'checkin-code-1',
      sessionId: 'session-1',
      userId: 'student-me',
      kind: kind,
      occurredAt: DateTime.utc(2026, 9, 20, 14),
      method: 'code',
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
    DateTime? tokenExpiresAt,
  }) => EvidenceSession(
    id: 'session-1',
    classId: classId,
    startsAt: DateTime.utc(2026, 9, 20, 13),
    endsAt: DateTime.utc(2026, 9, 20, 15),
    status: 'open',
    tokenExpiresAt:
        tokenExpiresAt ?? DateTime.now().add(sessionValidity),
    tokenVersion: version,
    checkinToken: includeToken ? 'token-$version' : null,
    checkinCode: includeToken ? '654321' : null,
  );
}

void _checkinViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('aluno registra a própria presença com código numérico', (
    tester,
  ) async {
    _checkinViewport(tester);
    final gateway = _FakeEvidenceGateway();
    await tester.pumpWidget(
      MaterialApp(home: EvidenceCheckinScreen(gateway: gateway)),
    );

    await tester.enterText(
      find.byKey(const ValueKey('session-code')),
      '332 456',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.pumpAndSettle();

    expect(find.text('Entrada confirmada'), findsOneWidget);
    expect(find.textContaining('evidence-student'), findsOneWidget);
    expect(find.textContaining('lista da turma'), findsOneWidget);
    expect(gateway.lastCode, '332456');
    expect(gateway.lastCodeKind, 'checkin');
    expect(gateway.lastIdempotencyKey, startsWith('mobile:'));
    expect(find.text('student-1'), findsNothing);
  });

  testWidgets('aluno pode colar o código completo do QR', (tester) async {
    _checkinViewport(tester);
    final gateway = _FakeEvidenceGateway();
    await tester.pumpWidget(
      MaterialApp(home: EvidenceCheckinScreen(gateway: gateway)),
    );

    await tester.tap(find.text('Usar código completo do QR'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('qr-uri')),
      'tutortds://checkin?class_id=class-1&session_id=session-1&token=token-1',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.pumpAndSettle();

    expect(find.text('Entrada confirmada'), findsOneWidget);
    expect(gateway.lastCode, isNull);
  });

  testWidgets('link do QR abre a tela e confirma sem digitar código', (
    tester,
  ) async {
    _checkinViewport(tester);
    final gateway = _FakeEvidenceGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: EvidenceCheckinScreen(
          gateway: gateway,
          initialUri:
              'tutortds://checkin?class_id=class-1&session_id=session-1&token=qr-secret',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entrada confirmada'), findsOneWidget);
    expect(gateway.lastToken, 'qr-secret');
    expect(gateway.lastIdempotencyKey, startsWith('mobile:'));
    expect(gateway.lastCode, isNull);
  });

  testWidgets('link do QR inválido mostra erro humano sem enviar', (
    tester,
  ) async {
    _checkinViewport(tester);
    final gateway = _FakeEvidenceGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: EvidenceCheckinScreen(
          gateway: gateway,
          initialUri: 'https://example.com/not-a-checkin',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não sincronizado'), findsOneWidget);
    expect(find.textContaining('Código incompleto'), findsOneWidget);
    expect(gateway.idempotencyKeys, isEmpty);
  });

  testWidgets('código do encontro exige exatamente 6 dígitos', (tester) async {
    _checkinViewport(tester);
    final gateway = _FakeEvidenceGateway();
    await tester.pumpWidget(
      MaterialApp(home: EvidenceCheckinScreen(gateway: gateway)),
    );

    await tester.enterText(find.byKey(const ValueKey('session-code')), '33245');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.pumpAndSettle();

    expect(find.text('O código do encontro tem 6 dígitos.'), findsOneWidget);
    expect(gateway.lastCode, isNull);
    expect(gateway.idempotencyKeys, isEmpty);
  });

  testWidgets('queda de rede mantém retry idempotente sem confirmar presença', (
    tester,
  ) async {
    _checkinViewport(tester);
    final gateway = _FakeEvidenceGateway()..failCheckinWithNetwork = true;
    await tester.pumpWidget(
      MaterialApp(home: EvidenceCheckinScreen(gateway: gateway)),
    );
    const code =
        'tutortds://checkin?class_id=class-1&session_id=session-1&token=secret-token';
    await tester.tap(find.text('Usar código completo do QR'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('qr-uri')), code);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.pumpAndSettle();

    expect(find.text('Não sincronizado'), findsOneWidget);
    expect(find.text('Presença pendente neste aparelho'), findsOneWidget);
    expect(find.text('Entrada confirmada'), findsNothing);
    final firstKey = gateway.lastIdempotencyKey;
    final raw = (await SharedPreferences.getInstance()).getString(
      SharedPreferencesCheckinDraftStore.storageKey,
    );
    expect(raw, isNotNull);
    expect(raw, isNot(contains('secret-token')));

    gateway.failCheckinWithNetwork = false;
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.pumpAndSettle();

    expect(find.text('Entrada confirmada'), findsOneWidget);
    expect(gateway.idempotencyKeys, [firstKey, firstKey]);
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        SharedPreferencesCheckinDraftStore.storageKey,
      ),
      isFalse,
    );
  });

  testWidgets(
    'reabertura recupera pendência sem token e exige código atual da sessão',
    (tester) async {
      _checkinViewport(tester);
      final gateway = _FakeEvidenceGateway()..failCheckinWithNetwork = true;
      await tester.pumpWidget(
        MaterialApp(home: EvidenceCheckinScreen(gateway: gateway)),
      );
      await tester.tap(find.text('Usar código completo do QR'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('qr-uri')),
        'tutortds://checkin?class_id=class-1&session_id=session-1&token=old-secret',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar entrada'));
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar entrada'));
      await tester.pumpAndSettle();
      final originalKey = gateway.lastIdempotencyKey;

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      gateway.failCheckinWithNetwork = false;
      await tester.pumpWidget(
        MaterialApp(home: EvidenceCheckinScreen(gateway: gateway)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Presença pendente neste aparelho'), findsOneWidget);
      expect(
        find.textContaining('código anterior não foi salvo'),
        findsOneWidget,
      );

      await tester.tap(find.text('Usar código completo do QR'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextFormField>(
        find.byKey(const ValueKey('qr-uri')),
      );
      expect(field.controller?.text, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('qr-uri')),
        'tutortds://checkin?class_id=class-1&session_id=session-1&token=fresh-secret',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar entrada'));
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar entrada'));
      await tester.pumpAndSettle();
      expect(find.text('Entrada confirmada'), findsOneWidget);
      expect(gateway.lastIdempotencyKey, originalKey);
    },
  );

  testWidgets('queda de rede com código numérico não salva o código', (
    tester,
  ) async {
    _checkinViewport(tester);
    final gateway = _FakeEvidenceGateway()..failCheckinWithNetwork = true;
    await tester.pumpWidget(
      MaterialApp(home: EvidenceCheckinScreen(gateway: gateway)),
    );

    await tester.enterText(find.byKey(const ValueKey('session-code')), '332456');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.pumpAndSettle();

    expect(find.text('Não sincronizado'), findsOneWidget);
    expect(find.text('Presença pendente neste aparelho'), findsOneWidget);
    expect(find.text('Entrada confirmada'), findsNothing);
    final raw = (await SharedPreferences.getInstance()).getString(
      SharedPreferencesCheckinDraftStore.storageKey,
    );
    expect(raw, isNotNull);
    expect(raw, contains('"via_code":true'));
    expect(raw, isNot(contains('332456')));
    expect(raw, isNot(contains('session-1')));

    gateway.failCheckinWithNetwork = false;
    await tester.enterText(find.byKey(const ValueKey('session-code')), '654321');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar entrada'));
    await tester.pumpAndSettle();

    expect(find.text('Entrada confirmada'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        SharedPreferencesCheckinDraftStore.storageKey,
      ),
      isFalse,
    );
  });

  testWidgets('equipe vê código do encontro e renovação automática no prazo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeEvidenceGateway()
      ..sessionValidity = const Duration(seconds: 3);
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

    await tester.ensureVisible(find.text('Abrir sessão agora'));
    await tester.tap(find.text('Abrir sessão agora'));
    await tester.pumpAndSettle();

    expect(find.textContaining('token v1'), findsOneWidget);
    expect(find.text('Código do encontro'), findsOneWidget);
    expect(find.text('654 321'), findsOneWidget);
    expect(find.textContaining('renovados automaticamente'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.textContaining('token v2'), findsOneWidget);
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
