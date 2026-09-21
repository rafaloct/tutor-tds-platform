import 'dart:convert';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/evidence/data/evidence_repository.dart';
import 'package:cartilhas_app/features/evidence/models/evidence_models.dart';
import 'package:cartilhas_app/features/evidence/presentation/session_presence_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> rowJson(String state) => {
  'user_id': 'student',
  'user_name': 'Ana',
  'enrollment_id': 'enrollment',
  'status': state,
  'revision': 0,
  'checkin_count': 1,
  'checkout_count': 0,
  'activity_count': 0,
  'reason': null,
  'decided_at': null,
};

class PresenceAuth implements AuthRepository {
  String? owner = 'teacher';
  @override
  Future<String?> localUserId() async => owner;
  @override
  Future<http.Response> authorized(
    Future<http.Response> Function(String) operation,
  ) => operation('access');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PresenceFake implements EvidenceGateway {
  String status = 'suggested_present';
  String sessionStatus = 'open';
  int decisions = 0, revision = 0;
  bool conflict = false;
  String? sentKey;
  int? sentRevision;
  @override
  Future<SessionPresencePage> presence(
    String classId,
    String sessionId, {
    int offset = 0,
  }) async => SessionPresencePage(
    items: [SessionPresence.fromJson(rowJson(status)..['revision'] = revision)],
    total: 1,
    offset: 0,
    limit: 50,
    sessionStatus: sessionStatus,
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
  }) async {
    decisions++;
    sentKey = idempotencyKey;
    sentRevision = expectedRevision;
    if (conflict) {
      throw const EvidenceApiException(
        'A decisão mudou. Atualize a lista.',
        statusCode: 409,
      );
    }
    this.status = status;
    revision++;
    return SessionPresence.fromJson(rowJson(status)..['revision'] = revision);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> showPresence(WidgetTester tester, PresenceFake fake) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SessionPresenceScreen(
        gateway: fake,
        classId: 'class-a',
        sessionId: 'session-a',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> chooseDecision(WidgetTester tester, String label) async {
  await tester.tap(find.text('Registrar decisão'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), 'Conferido com a equipe');
  await tester.tap(find.text('Confirmar decisão'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'presence uses existing authenticated repository and preserves API prefix',
    () async {
      final auth = PresenceAuth();
      final requests = <http.Request>[];
      final repo = EvidenceRepository(
        apiUrl: 'https://example.test/staging-api',
        authRepository: auth,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(
              request.method == 'GET'
                  ? {
                      'items': [rowJson('suggested_present')],
                      'total': 1,
                      'offset': 0,
                      'limit': 50,
                      'session_status': 'open',
                    }
                  : rowJson('confirmed_present'),
            ),
            200,
          );
        }),
      );
      addTearDown(repo.dispose);
      final page = await repo.presence('class-a', 'session-a');
      expect(page.items.single.status, 'suggested_present');
      expect(
        requests.single.url.path,
        '/staging-api/classes/class-a/sessions/session-a/presence',
      );
      expect(requests.single.headers['authorization'], 'Bearer access');
      await repo.decidePresence(
        classId: 'class-a',
        sessionId: 'session-a',
        userId: 'student',
        status: 'confirmed_present',
        expectedRevision: 0,
        reason: '  Conferido  ',
        idempotencyKey: 'presence:unique',
      );
      expect(jsonDecode(requests.last.body), {
        'status': 'confirmed_present',
        'expected_revision': 0,
        'reason': 'Conferido',
        'idempotency_key': 'presence:unique',
      });
    },
  );

  test(
    'account change discards presence response and prevents later writes',
    () async {
      final auth = PresenceAuth();
      int calls = 0;
      final repo = EvidenceRepository(
        apiUrl: 'https://example.test',
        authRepository: auth,
        client: MockClient((_) async {
          calls++;
          auth.owner = 'other';
          return http.Response('{}', 200);
        }),
      );
      addTearDown(repo.dispose);
      await expectLater(
        repo.presence('class', 'session'),
        throwsA(
          isA<EvidenceApiException>().having(
            (e) => e.statusCode,
            'status',
            401,
          ),
        ),
      );
      await expectLater(
        repo.decidePresence(
          classId: 'class',
          sessionId: 'session',
          userId: 'student',
          status: 'absent',
          expectedRevision: 0,
          reason: 'Conferido',
          idempotencyKey: 'presence:unique',
        ),
        throwsA(isA<EvidenceApiException>()),
      );
      expect(calls, 1);
    },
  );

  test('automatic suggestion cannot be sent as human decision', () async {
    final repo = EvidenceRepository(
      apiUrl: 'https://example.test',
      authRepository: PresenceAuth(),
      client: MockClient((_) async => throw StateError('must not send')),
    );
    addTearDown(repo.dispose);
    await expectLater(
      repo.decidePresence(
        classId: 'class',
        sessionId: 'session',
        userId: 'student',
        status: 'suggested_present',
        expectedRevision: 0,
        reason: 'Conferido',
        idempotencyKey: 'presence:unique',
      ),
      throwsA(isA<EvidenceApiException>()),
    );
  });

  testWidgets('QR remains suggestion until explicit reasoned human decision', (
    tester,
  ) async {
    final fake = PresenceFake();
    await showPresence(tester, fake);
    expect(fake.decisions, 0);
    expect(
      find.text('Indício de presença — aguarda conferência'),
      findsOneWidget,
    );
    await tester.tap(find.text('Registrar decisão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar decisão'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha a decisão.'), findsOneWidget);
    expect(find.text('Informe uma justificativa.'), findsOneWidget);
    expect(fake.decisions, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await chooseDecision(tester, 'Presença confirmada pela equipe');
    expect(fake.decisions, 1);
    expect(fake.sentRevision, 0);
    expect(fake.sentKey, startsWith('presence:'));
    expect(find.text('Presença confirmada pela equipe'), findsOneWidget);
  });

  testWidgets('conflict does not optimistically mark absence', (tester) async {
    final fake = PresenceFake()..conflict = true;
    await showPresence(tester, fake);
    await chooseDecision(tester, 'Ausência justificada');
    expect(find.text('A decisão mudou. Atualize a lista.'), findsOneWidget);
    expect(
      find.text('Indício de presença — aguarda conferência'),
      findsOneWidget,
    );
    expect(find.text('Ausência justificada'), findsNothing);
  });

  testWidgets('closed session is read-only', (tester) async {
    await showPresence(
      tester,
      PresenceFake()
        ..sessionStatus = 'closed'
        ..status = 'absent',
    );
    expect(find.text('Registrar decisão'), findsNothing);
    expect(find.text('Ausência registrada pela equipe'), findsOneWidget);
  });

  testWidgets('presence card works with 200 percent text on narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await showPresence(tester, PresenceFake());
    await tester.scrollUntilVisible(find.text('Registrar decisão'), 150);
    await tester.pumpAndSettle();
    expect(find.text('Registrar decisão').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
