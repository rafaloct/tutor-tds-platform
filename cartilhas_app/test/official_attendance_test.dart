import 'dart:async';
import 'dart:convert';
import 'package:cartilhas_app/features/evidence/data/evidence_repository.dart';
import 'package:cartilhas_app/features/evidence/models/evidence_models.dart';
import 'package:cartilhas_app/features/evidence/presentation/official_attendance_screen.dart';
import 'package:cartilhas_app/features/evidence/presentation/session_presence_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'session_presence_test.dart' show PresenceAuth, PresenceFake, rowJson;

class DelayedRoster extends PresenceFake {
  Completer<SessionPresencePage>? pending;
  String name = 'B';
  @override
  Future<SessionPresencePage> presence(
    String classId,
    String sessionId, {
    int offset = 0,
  }) async =>
      pending?.future ??
      SessionPresencePage(
        items: [
          SessionPresence.fromJson({...rowJson('pending'), 'user_name': name}),
        ],
        total: 1,
        offset: 0,
        limit: 50,
        sessionStatus: 'closed',
      );
}

Map<String, dynamic> page({bool allowed = true, String? reason}) => {
  'items': [
    if (reason != null)
      {
        'revision': 1,
        'status': 'VALID',
        'reason': reason,
        'makeup_session_id': null,
        'decided_at': '2026-10-03T12:00:00Z',
      },
  ],
  'total': reason == null ? 0 : 1,
  'can_decide': allowed,
};

class AttendanceFake implements EvidenceGateway, OfficialAttendanceGateway {
  bool allowed = true;
  String? savedStatus, savedReason, savedKey;
  Completer<OfficialAttendancePage>? pending;
  @override
  Future<OfficialAttendancePage> attendanceHistory(
    String classId,
    String sessionId,
    String userId, {
    int offset = 0,
  }) async =>
      pending?.future ??
      OfficialAttendancePage.fromJson(
        page(allowed: allowed, reason: savedReason),
      );
  @override
  Future<EvidenceSessionPage> attendanceSessions(
    String classId, {
    int offset = 0,
  }) async =>
      EvidenceSessionPage(sessions: [], total: 0, limit: 100, offset: 0);
  @override
  Future<void> decideAttendance({
    required String classId,
    required String sessionId,
    required String userId,
    required String status,
    required int expectedRevision,
    required String reason,
    required String idempotencyKey,
    String? makeupSessionId,
  }) async {
    savedStatus = status;
    savedReason = reason;
    savedKey = idempotencyKey;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('parent roster target switch also rejects late A data', (
    tester,
  ) async {
    final old = DelayedRoster()..pending = Completer<SessionPresencePage>();
    final current = DelayedRoster();
    await tester.pumpWidget(
      MaterialApp(
        home: SessionPresenceScreen(gateway: old, classId: 'A', sessionId: 's'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SessionPresenceScreen(
          gateway: current,
          classId: 'B',
          sessionId: 's',
        ),
      ),
    );
    await tester.pumpAndSettle();
    old.pending!.complete(
      SessionPresencePage(
        items: [
          SessionPresence.fromJson({
            ...rowJson('pending'),
            'user_name': 'Private A',
          }),
        ],
        total: 1,
        offset: 0,
        limit: 50,
        sessionStatus: 'closed',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });
  test(
    'official requests preserve owner boundary across late A to B response',
    () async {
      final auth = PresenceAuth();
      final pending = Completer<http.Response>();
      final repository = EvidenceRepository(
        apiUrl: 'https://api.example/tutor-api',
        authRepository: auth,
        client: MockClient((request) {
          expect(
            request.url.path,
            '/tutor-api/classes/c/sessions/s/attendance/u',
          );
          return pending.future;
        }),
      );
      final result = repository.attendanceHistory('c', 's', 'u');
      await Future<void>.delayed(Duration.zero);
      auth.owner = 'other';
      pending.complete(
        http.Response(jsonEncode(page(reason: 'Private A')), 200),
      );
      await expectLater(result, throwsA(isA<EvidenceApiException>()));
      await expectLater(
        repository.attendanceSessions('c'),
        throwsA(isA<EvidenceApiException>()),
      );
    },
  );
  test(
    'decision uses original route, explicit status revision reason and makeup',
    () async {
      final repository = EvidenceRepository(
        apiUrl: 'https://api.example',
        authRepository: PresenceAuth(),
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/classes/c/sessions/original/attendance/u');
          expect(jsonDecode(request.body), {
            'status': 'PENDING_MAKEUP',
            'expected_revision': 2,
            'reason': 'Reviewed',
            'idempotency_key': 'synthetic-key',
            'makeup_session_id': 'replacement',
          });
          return http.Response('{}', 200);
        }),
      );
      await repository.decideAttendance(
        classId: 'c',
        sessionId: 'original',
        userId: 'u',
        status: 'PENDING_MAKEUP',
        expectedRevision: 2,
        reason: 'Reviewed',
        idempotencyKey: 'synthetic-key',
        makeupSessionId: 'replacement',
      );
    },
  );
  testWidgets(
    'official decision and history work at 360px without automatic validation',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fake = AttendanceFake();
      await tester.pumpWidget(
        MaterialApp(
          home: OfficialAttendanceScreen(
            gateway: fake,
            classId: 'c',
            sessionId: 's',
            userId: 'u',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fake.savedStatus, isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Presença válida').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Conferência explícita',
      );
      await tester.ensureVisible(find.text('Registrar decisão oficial'));
      await tester.tap(find.text('Registrar decisão oficial'));
      await tester.pumpAndSettle();
      expect(fake.savedStatus, 'VALID');
      expect(fake.savedKey, startsWith('attendance:'));
      expect(find.text('Conferência explícita'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'target switch rejects delayed old history and permission defaults denied',
    (tester) async {
      final old = AttendanceFake()
        ..pending = Completer<OfficialAttendancePage>();
      final current = AttendanceFake()..allowed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: OfficialAttendanceScreen(
            gateway: old,
            classId: 'A',
            sessionId: 's',
            userId: 'u',
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: OfficialAttendanceScreen(
            gateway: current,
            classId: 'B',
            sessionId: 's',
            userId: 'u',
          ),
        ),
      );
      await tester.pumpAndSettle();
      old.pending!.complete(
        OfficialAttendancePage.fromJson(page(reason: 'History A')),
      );
      await tester.pumpAndSettle();
      expect(find.text('History A'), findsNothing);
      expect(find.text('Registrar decisão oficial'), findsNothing);
    },
  );
}
