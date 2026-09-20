import 'dart:convert';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/evidence/data/evidence_repository.dart';
import 'package:cartilhas_app/features/evidence/models/evidence_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenStore implements AuthTokenStore {
  AuthTokens? tokens = const AuthTokens(
    accessToken: 'access',
    refreshToken: 'refresh',
  );

  @override
  Future<void> clear() async => tokens = null;
  @override
  Future<AuthTokens?> read() async => tokens;
  @override
  Future<void> write(AuthTokens tokens) async => this.tokens = tokens;
}

void main() {
  test('consome sessão, QR, check-in e exceções com autenticação', () async {
    final requests = <http.Request>[];
    final auth = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response('{}', 500)),
      tokenStore: _TokenStore(),
    );
    final repository = EvidenceRepository(
      apiUrl: 'https://api.example',
      authRepository: auth,
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer access');
        final path = request.url.path;
        if (path.endsWith('/sessions')) {
          return http.Response(jsonEncode(_sessionJson(token: 'token-1')), 201);
        }
        if (path.endsWith('/token')) {
          return http.Response(jsonEncode(_sessionJson(token: 'token-2')), 200);
        }
        if (path.endsWith('/checkins')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['idempotency_key'], 'mobile:12345678');
          expect(body, isNot(contains('user_id')));
          return http.Response(
            jsonEncode({
              'id': 'check-1',
              'session_id': 'session-1',
              'user_id': 'me',
              'kind': 'checkin',
              'occurred_at': '2026-09-20T14:00:00Z',
              'method': 'qr',
              'evidence_id': 'evidence-1',
            }),
            201,
          );
        }
        if (path.endsWith('/exceptions')) {
          return http.Response(
            jsonEncode({
              'exceptions': [
                {
                  'code': 'evidence_needs_review',
                  'user_id': 'me',
                  'evidence_id': 'evidence-1',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );

    final session = await repository.createSession(
      classId: 'class-1',
      startsAt: DateTime.utc(2026, 9, 20, 13),
      endsAt: DateTime.utc(2026, 9, 20, 15),
    );
    final rotated = await repository.rotateToken('class-1', session.id);
    final checkin = await repository.checkin(
      classId: 'class-1',
      sessionId: session.id,
      kind: 'checkin',
      idempotencyKey: 'mobile:12345678',
      token: rotated.checkinToken!,
    );
    final exceptions = await repository.exceptions('class-1');

    expect(session.checkinToken, 'token-1');
    expect(rotated.checkinToken, 'token-2');
    expect(checkin.evidenceId, 'evidence-1');
    expect(exceptions.single.userId, 'me');
    expect(requests, hasLength(4));
  });

  test('importa somente metadados estruturados e consulta relatório', () async {
    late Map<String, dynamic> importBody;
    final auth = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response('{}', 500)),
      tokenStore: _TokenStore(),
    );
    final repository = EvidenceRepository(
      apiUrl: 'https://api.example',
      authRepository: auth,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/evidence-imports')) {
          importBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 'import-1',
              'class_id': 'class-1',
              'source_type': 'drive_metadata',
              'status': 'pending_review',
              'retention_until': '2026-10-20T00:00:00Z',
              'source_digest': _hex('a'),
              'evidence_ids': ['evidence-1'],
            }),
            201,
          );
        }
        if (request.url.path.contains('/reports/')) {
          return http.Response(jsonEncode(_reportJson()), 200);
        }
        return http.Response('{}', 404);
      }),
    );

    final imported = await repository.createImport(
      classId: 'class-1',
      sourceType: 'drive_metadata',
      sourceDigest: _hex('a'),
      idempotencyKey: 'import:12345678',
      retentionUntil: DateTime.utc(2026, 10, 20),
      items: [
        EvidenceImportItemDraft(
          itemDigest: _hex('b'),
          evidenceType: 'document_metadata',
          occurredAt: DateTime.utc(2026, 9, 20),
          metadata: const {'mime_type': 'application/pdf'},
        ),
      ],
    );
    final report = await repository.report('class-1', 'report-1');

    expect(imported.status, 'pending_review');
    expect(importBody.toString(), isNot(contains('conversa')));
    expect(importBody['items'], hasLength(1));
    expect(report.reportDigest, 'digest-report');
  });

  test(
    'lista e recupera sessões sem reexpor token; 404 vira ausência',
    () async {
      final auth = AuthRepository(
        apiUrl: 'https://api.example',
        client: MockClient((_) async => http.Response('{}', 500)),
        tokenStore: _TokenStore(),
      );
      final view = Map<String, dynamic>.from(_sessionJson(token: 'remover'))
        ..remove('checkin_token')
        ..['token_version'] = 1;
      final repository = EvidenceRepository(
        apiUrl: 'https://api.example',
        authRepository: auth,
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer access');
          if (request.url.path.endsWith('/sessions/open')) {
            return http.Response(jsonEncode(view), 200);
          }
          if (request.url.path.endsWith('/sessions/missing')) {
            return http.Response(
              jsonEncode({'detail': 'Sessão não encontrada.'}),
              404,
            );
          }
          if (request.url.path.endsWith('/sessions/session-1')) {
            return http.Response(jsonEncode(view), 200);
          }
          if (request.url.path.endsWith('/sessions')) {
            expect(request.url.queryParameters['status'], 'open');
            expect(request.url.queryParameters['limit'], '25');
            expect(request.url.queryParameters['offset'], '5');
            return http.Response(
              jsonEncode({
                'sessions': [view],
                'total': 1,
                'limit': 25,
                'offset': 5,
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final page = await repository.listSessions(
        'class-1',
        status: 'open',
        limit: 25,
        offset: 5,
      );
      final open = await repository.openSession('class-1');
      final byId = await repository.session('class-1', 'session-1');
      final missing = await repository.session('class-1', 'missing');

      expect(page.total, 1);
      expect(page.sessions.single.checkinToken, isNull);
      expect(open?.id, 'session-1');
      expect(open?.checkinToken, isNull);
      expect(byId?.tokenVersion, 1);
      expect(byId?.checkinToken, isNull);
      expect(missing, isNull);
    },
  );

  test('sessão aberta 404 é estado vazio, não falha', () async {
    final auth = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response('{}', 500)),
      tokenStore: _TokenStore(),
    );
    final repository = EvidenceRepository(
      apiUrl: 'https://api.example',
      authRepository: auth,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Sessão aberta não encontrada.'}),
          404,
        ),
      ),
    );

    expect(await repository.openSession('class-1'), isNull);
  });

  test('rejeita texto bruto e preserva conflito de fechamento', () async {
    expect(
      () => EvidenceImportItemDraft(
        itemDigest: _hex('b'),
        evidenceType: 'message_metadata',
        occurredAt: DateTime.utc(2026),
        metadata: const {'message_count': 'linha 1\ntexto bruto'},
      ).toJson(),
      throwsFormatException,
    );

    final auth = AuthRepository(
      apiUrl: 'https://api.example',
      client: MockClient((_) async => http.Response('{}', 500)),
      tokenStore: _TokenStore(),
    );
    final repository = EvidenceRepository(
      apiUrl: 'https://api.example',
      authRepository: auth,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Há evidências pendentes.'}),
          409,
        ),
      ),
    );
    await expectLater(
      repository.closeSession(classId: 'class-1', sessionId: 'session-1'),
      throwsA(
        isA<EvidenceApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          409,
        ),
      ),
    );
  });
}

Map<String, dynamic> _sessionJson({required String token}) => {
  'id': 'session-1',
  'class_id': 'class-1',
  'starts_at': '2026-09-20T13:00:00Z',
  'ends_at': '2026-09-20T15:00:00Z',
  'status': 'open',
  'token_expires_at': '2026-09-20T14:10:00Z',
  'token_version': token == 'token-1' ? 1 : 2,
  'checkin_token': token,
};

String _hex(String character) => List.filled(64, character).join();

Map<String, dynamic> _reportJson() => {
  'id': 'report-1',
  'class_id': 'class-1',
  'session_id': 'session-1',
  'generated_at': '2026-09-20T15:00:00Z',
  'report_digest': 'digest-report',
  'summary': {'checkin_count': 3, 'pending_evidence_ids': <String>[]},
};
