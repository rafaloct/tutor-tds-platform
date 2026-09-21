import 'dart:async';
import 'dart:convert';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/certificates/data/certificate_request_repository.dart';
import 'package:cartilhas_app/features/certificates/models/certificate_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Store implements AuthTokenStore {
  AuthTokens? value = AuthTokens(
    accessToken: _accessFor('owner-1'),
    refreshToken: 'test-refresh',
  );
  @override
  Future<AuthTokens?> read() async => value;
  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
  @override
  Future<void> clear() async => value = null;
}

String _accessFor(String subject) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': subject}))).replaceAll('=', '')}.signature';

Map<String, dynamic> _eligibility() => {
  'required_seconds': 3600,
  'validated_seconds': 4000,
  'completed': true,
  'eligible': true,
};
Map<String, dynamic> _context({String? classId = 'class-1'}) => {
  'enrollment_id': 'enrollment-1',
  'program_name': 'Programa Educação',
  'class_id': classId,
  'class_name': classId == null ? null : 'Turma A',
  'course_version_id': 'version-1',
  'course_title': 'Curso Agricultura',
  'eligibility': _eligibility(),
};
Map<String, dynamic> _dto() => {
  'id': 'request-1',
  'enrollment_id': 'enrollment-1',
  'course_id': 'course-1',
  'course_version_id': 'version-1',
  'class_id': 'class-1',
  'program_id': 'program-1',
  'holder_name': 'Pessoa de Teste',
  'course_title': 'Curso Agricultura',
  'program_name': 'Programa Educação',
  'institution_name': 'Instituição TDS',
  'status': 'pending',
  'revision': 2,
  'requested_at': '2026-09-21T12:34:56Z',
  'reviewed_at': null,
  'review_reason': null,
  'eligibility': _eligibility(),
};
http.Response _json(Object json, [int status = 200]) => http.Response(
  jsonEncode(json),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

CertificateRequestRepository _repository(
  Future<http.Response> Function(http.Request) handler, {
  _Store? store,
}) {
  final auth = AuthRepository(
    apiUrl: 'https://api.example/tds/v1/',
    tokenStore: store ?? _Store(),
    client: MockClient(
      (_) async => _json({
        'access_token': _accessFor('owner-1'),
        'refresh_token': 'renewed-refresh',
        'user': {'id': 'u1', 'name': 'Pessoa', 'role': 'student'},
      }),
    ),
  );
  addTearDown(auth.dispose);
  final repository = CertificateRequestRepository(
    apiUrl: 'https://api.example/tds/v1/',
    authRepository: auth,
    client: MockClient(handler),
  );
  addTearDown(repository.dispose);
  return repository;
}

void main() {
  for (final logout in [false, true]) {
    test(
      'rejects response after ${logout ? 'logout' : 'account replacement'}',
      () async {
        final store = _Store();
        final repository = _repository((_) async {
          store.value = logout
              ? null
              : AuthTokens(
                  accessToken: _accessFor('owner-2'),
                  refreshToken: 'next-refresh',
                );
          return _json(_dto());
        }, store: store);
        await expectLater(
          repository.detail('id'),
          throwsA(
            isA<CertificateRequestException>().having(
              (e) => e.statusCode,
              'session changed',
              401,
            ),
          ),
        );
      },
    );
  }
  test(
    'repository remains bound to first owner across sequential calls',
    () async {
      final store = _Store();
      var calls = 0;
      final repository = _repository((_) async {
        calls++;
        return _json({
          'requests': [_dto()],
        });
      }, store: store);
      expect(
        (await repository.ownRequests()).single.holderName,
        'Pessoa de Teste',
      );
      store.value = AuthTokens(
        accessToken: _accessFor('owner-2'),
        refreshToken: 'next-refresh',
      );
      await expectLater(
        repository.contexts('course', 'version'),
        throwsA(
          isA<CertificateRequestException>().having(
            (e) => e.statusCode,
            'session changed',
            401,
          ),
        ),
      );
      expect(calls, 1);
    },
  );
  test('malformed local JWT cannot select personal request data', () async {
    var calls = 0;
    final store = _Store()
      ..value = const AuthTokens(
        accessToken: 'malformed',
        refreshToken: 'refresh',
      );
    final repository = _repository((_) async {
      calls++;
      return _json({'requests': []});
    }, store: store);
    await expectLater(
      repository.ownRequests(),
      throwsA(
        isA<CertificateRequestException>().having(
          (e) => e.statusCode,
          'session invalid',
          401,
        ),
      ),
    );
    expect(calls, 0);
  });
  test(
    'review reason obeys backend range without sending invalid mutation',
    () {
      var calls = 0;
      final repository = _repository((_) async {
        calls++;
        return _json(_dto());
      });
      for (final reason in ['  ', 'ab', 'x' * 501]) {
        expect(
          () => repository.review('id', 'approve', 1, reason),
          throwsA(
            isA<CertificateRequestException>().having(
              (e) => e.statusCode,
              'invalid reason',
              422,
            ),
          ),
        );
      }
      expect(calls, 0);
    },
  );
  test(
    'contexts preserves API prefix and encodes version/course query safely',
    () async {
      final repository = _repository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/tds/v1/certificate-requests/contexts');
        expect(request.url.queryParameters, {
          'course_id': 'course & admin=true',
          'course_version_id': 'v/1?x=2',
        });
        expect(
          request.headers['authorization'],
          'Bearer ${_accessFor('owner-1')}',
        );
        return _json({
          'contexts': [_context()],
        });
      });
      final contexts = await repository.contexts(
        'course & admin=true',
        'v/1?x=2',
      );
      expect(contexts.single.programName, 'Programa Educação');
      expect(contexts.single.eligibility.requiredSeconds, 3600);
      expect(contexts.single.eligibility.validatedSeconds, 4000);
      expect(contexts.single.eligibility.eligible, isTrue);
      expect(() => contexts.clear(), throwsUnsupportedError);
    },
  );

  test(
    'create sends only server context IDs and explicit nullable class',
    () async {
      for (final classId in [null, 'class-1']) {
        final contextJson = {
          ..._context(classId: classId),
          'status': 'approved',
          'holder_name': 'injected-name',
          'admin': true,
        };
        final repository = _repository((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/tds/v1/certificate-requests');
          expect(jsonDecode(request.body), {
            'enrollment_id': 'enrollment-1',
            'course_version_id': 'version-1',
            'class_id': classId,
          });
          return _json({..._dto(), 'class_id': classId}, 201);
        });
        final created = await repository.create(
          CertificateRequestContext.fromJson(contextJson),
        );
        expect(created.status, 'pending');
        expect(created.classId, classId);
        expect(created.holderName, 'Pessoa de Teste');
      }
    },
  );

  test(
    'own list, review queue and detail use separate authenticated endpoints',
    () async {
      final paths = <String>[];
      final repository = _repository((request) async {
        paths.add(request.url.toString());
        expect(
          request.headers['authorization'],
          'Bearer ${_accessFor('owner-1')}',
        );
        return paths.length < 3
            ? _json({
                'requests': [_dto()],
              })
            : _json(_dto());
      });
      expect((await repository.ownRequests()).single.id, 'request-1');
      expect(
        (await repository.reviewQueue()).single.institutionName,
        'Instituição TDS',
      );
      expect(
        (await repository.detail('id/review?decision=approve')).revision,
        2,
      );
      expect(paths, [
        'https://api.example/tds/v1/certificate-requests',
        'https://api.example/tds/v1/certificate-requests/review-queue',
        'https://api.example/tds/v1/certificate-requests/id%2Freview%3Fdecision%3Dapprove',
      ]);
    },
  );

  test(
    'review sends exact decision/revision/reason and resubmit only revision',
    () async {
      final requests = <http.Request>[];
      final repository = _repository((request) async {
        requests.add(request);
        return _json(_dto());
      });
      const reason = 'Conferido: "texto", expected_revision=999';
      await repository.review('id/1', 'approve', 2, reason);
      expect(requests.last.method, 'POST');
      expect(requests.last.url.toString(), endsWith('/id%2F1/review'));
      expect(jsonDecode(requests.last.body), {
        'decision': 'approve',
        'expected_revision': 2,
        'reason': reason,
      });
      await repository.review('id/1', 'reject', 3, 'Faltam horas');
      expect(jsonDecode(requests.last.body), {
        'decision': 'reject',
        'expected_revision': 3,
        'reason': 'Faltam horas',
      });
      await repository.resubmit('id/1', 4);
      expect(requests.last.url.toString(), endsWith('/id%2F1/resubmit'));
      expect(jsonDecode(requests.last.body), {'expected_revision': 4});
    },
  );

  test(
    'invalid local decisions, revisions and traversal IDs never call network',
    () {
      var calls = 0;
      final repository = _repository((_) async {
        calls++;
        return _json(_dto());
      });
      expect(
        () => repository.review('id', 'approve/admin', 1, ''),
        throwsA(isA<CertificateRequestException>()),
      );
      expect(
        () => repository.resubmit('id', 0),
        throwsA(isA<CertificateRequestException>()),
      );
      expect(
        () => repository.detail('..'),
        throwsA(isA<CertificateRequestException>()),
      );
      expect(
        () => repository.contexts('', 'v1'),
        throwsA(isA<CertificateRequestException>()),
      );
      expect(calls, 0);
    },
  );

  for (final status in [401, 403, 404, 409, 422, 503, 500]) {
    test('HTTP $status maps safe error without response echo', () async {
      final repository = _repository(
        (_) async => _json({
          'detail': 'PRIVATE_NAME secret-token <script>approve()</script>',
        }, status),
      );
      await expectLater(
        repository.detail('id'),
        throwsA(
          isA<CertificateRequestException>()
              .having((e) => e.statusCode, 'statusCode', status)
              .having((e) => e.conflict, 'conflict', status == 409)
              .having(
                (e) => e.message,
                'safe message',
                isNot(contains('PRIVATE_NAME')),
              )
              .having(
                (e) => e.message,
                'safe message',
                isNot(contains('secret-token')),
              ),
        ),
      );
    });
  }

  test(
    'strict model parsing rejects incomplete/invalid DTOs and impossible dates',
    () {
      for (final patch in <Map<String, dynamic>>[
        {'id': null},
        {'holder_name': 4},
        {'status': 'admin'},
        {'revision': 0},
        {'revision': 1.5},
        {'requested_at': 'private data'},
        {'requested_at': '2026-09-21T12:00:00'},
        {'requested_at': '2026-02-30T12:00:00Z'},
        {'reviewed_at': 123},
        {'class_id': false},
        {'eligibility': null},
        {
          'eligibility': {..._eligibility(), 'eligible': 'true'},
        },
        {
          'eligibility': {..._eligibility(), 'validated_seconds': -1},
        },
      ]) {
        expect(
          () => CertificateRequest.fromJson({..._dto(), ...patch}),
          throwsFormatException,
        );
      }
      final approved = CertificateRequest.fromJson({
        ..._dto(),
        'status': 'approved',
        'reviewed_at': '2026-09-21T13:00:00+00:00',
        'review_reason': 'Conferido',
      });
      expect(approved.reviewedAt, DateTime.utc(2026, 9, 21, 13));
      expect(approved.reviewReason, 'Conferido');
    },
  );

  test(
    'malformed successful responses are rejected safely, not silently filtered',
    () async {
      for (final payload in <Object>[
        [],
        {'requests': null},
        {
          'requests': [_dto(), 'PRIVATE_NAME'],
        },
        {
          'requests': [
            {..._dto(), 'revision': 'PRIVATE_NAME'},
          ],
        },
      ]) {
        final repository = _repository((_) async => _json(payload));
        await expectLater(
          repository.ownRequests(),
          throwsA(
            isA<CertificateRequestException>().having(
              (e) => e.message,
              'safe message',
              isNot(contains('PRIVATE_NAME')),
            ),
          ),
        );
      }
    },
  );

  test(
    'transport failures keep approval unqueued and do not expose details',
    () async {
      var requests = 0;
      final repository = _repository((_) async {
        requests++;
        throw TimeoutException('PRIVATE_NAME');
      });
      await expectLater(
        repository.review('id', 'approve', 1, 'Conferido'),
        throwsA(
          isA<CertificateRequestException>().having(
            (e) => e.message,
            'safe message',
            isNot(contains('PRIVATE_NAME')),
          ),
        ),
      );
      expect(requests, 1);
    },
  );

  test('missing authentication does not send a request', () async {
    var calls = 0;
    final repository = _repository((_) async {
      calls++;
      return _json(_dto());
    }, store: _Store()..value = null);
    await expectLater(
      repository.ownRequests(),
      throwsA(isA<CertificateRequestException>()),
    );
    expect(calls, 0);
  });
}
