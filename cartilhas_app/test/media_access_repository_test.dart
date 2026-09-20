import 'dart:convert';

import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/data/auth_token_store.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:cartilhas_app/features/media/data/media_repository.dart';
import 'package:cartilhas_app/features/media/models/media_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TokenStore implements AuthTokenStore {
  _TokenStore(this.value);
  AuthTokens? value;

  @override
  Future<void> clear() async => value = null;
  @override
  Future<AuthTokens?> read() async => value;
  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'autoriza playback restrito, resolve 307 sem Bearer e não persiste token',
    () async {
      final requests = <http.Request>[];
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 5));
      final repository = _repository((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          expect(request.headers['authorization'], 'Bearer access');
          expect(request.body, isEmpty);
          return http.Response(
            jsonEncode({
              'media_id': 'media-1',
              'playback_url':
                  'https://api.example/media/media-1/playback/opaque-token',
              'expires_at': expiresAt.toIso8601String(),
              'token_type': 'media_playback',
            }),
            201,
          );
        }
        expect(request.url.path, '/media/media-1/playback/opaque-token');
        expect(request.headers, isNot(contains('authorization')));
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          307,
          headers: {
            'location': 'https://www.youtube-nocookie.com/embed/AbCdEf12345',
          },
        );
      });

      final access = await repository.authorizePlayback(_restrictedMedia());

      expect(requests.map((request) => request.method), ['POST', 'GET']);
      expect(access.media.canPlay, isTrue);
      expect(access.media.providerAssetId, 'AbCdEf12345');
      expect(access.expiresAt, expiresAt);
      final stored = (await SharedPreferences.getInstance()).getKeys().join();
      expect(stored, isNot(contains('opaque-token')));
    },
  );

  test(
    'preserva subpath da API sem barra final no playback e na resolução',
    () async {
      final requests = <http.Request>[];
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 5));
      final repository = _repository((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          expect(
            request.url.toString(),
            'https://api.example/tutor-staging-api/media/media-1/playback-authorizations',
          );
          return http.Response(
            jsonEncode({
              'media_id': 'media-1',
              'playback_url':
                  'https://api.example/tutor-staging-api/media/media-1/playback/opaque-token',
              'expires_at': expiresAt.toIso8601String(),
              'token_type': 'media_playback',
            }),
            201,
          );
        }
        expect(
          request.url.toString(),
          'https://api.example/tutor-staging-api/media/media-1/playback/opaque-token',
        );
        expect(request.headers, isNot(contains('authorization')));
        return http.Response(
          '',
          307,
          headers: {
            'location': 'https://www.youtube-nocookie.com/embed/AbCdEf12345',
          },
        );
      }, apiUrl: 'https://api.example/tutor-staging-api');

      final access = await repository.authorizePlayback(_restrictedMedia());

      expect(requests.map((request) => request.method), ['POST', 'GET']);
      expect(access.media.canPlay, isTrue);
    },
  );

  test('rejeita redirect para provider inseguro', () async {
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 5));
    final repository = _repository((request) async {
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'media_id': 'media-1',
            'playback_url':
                'https://api.example/media/media-1/playback/opaque-token',
            'expires_at': expiresAt.toIso8601String(),
            'token_type': 'media_playback',
          }),
          201,
        );
      }
      return http.Response(
        '',
        307,
        headers: {'location': 'https://drive.google.com/file/provider-video'},
      );
    });

    await expectLater(
      repository.authorizePlayback(_restrictedMedia()),
      throwsA(
        isA<MediaRepositoryException>().having(
          (error) => error.issue,
          'issue',
          MediaRepositoryIssue.invalidResponse,
        ),
      ),
    );
  });

  test('token expirado e sessão ausente ficam observáveis', () async {
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 5));
    final expired = _repository((request) async {
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'media_id': 'media-1',
            'playback_url':
                'https://api.example/media/media-1/playback/opaque-token',
            'expires_at': expiresAt.toIso8601String(),
            'token_type': 'media_playback',
          }),
          201,
        );
      }
      return http.Response('{}', 401);
    });
    await expectLater(
      expired.authorizePlayback(_restrictedMedia()),
      throwsA(
        isA<MediaRepositoryException>().having(
          (error) => error.issue,
          'issue',
          MediaRepositoryIssue.authorizationExpired,
        ),
      ),
    );

    var called = false;
    final signedOut = _repository((_) async {
      called = true;
      return http.Response('{}', 500);
    }, signedIn: false);
    await expectLater(
      signedOut.authorizePlayback(_restrictedMedia()),
      throwsA(
        isA<MediaRepositoryException>().having(
          (error) => error.issue,
          'issue',
          MediaRepositoryIssue.sessionRequired,
        ),
      ),
    );
    expect(called, isFalse);
  });

  test('avalia com payload fechado e só confirma pela resposta', () async {
    late Map<String, dynamic> body;
    final repository = _repository((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'media_id': 'media-1',
          'rating': 4,
          'submitted_at': '2026-09-20T12:00:00Z',
          'updated_at': '2026-09-20T12:00:00Z',
        }),
        201,
      );
    });

    final rating = await repository.rate('media-1', 4);

    expect(body, {'rating': 4});
    expect(rating.rating, 4);
  });

  test('preserva subpath da API sem barra final no rating GET e PUT', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) async {
      requests.add(request);
      expect(
        request.url.toString(),
        'https://api.example/tutor-staging-api/media/media-1/rating',
      );
      if (request.method == 'GET') {
        return http.Response('{}', 404);
      }
      expect(jsonDecode(request.body), {'rating': 5});
      return http.Response(
        jsonEncode({
          'media_id': 'media-1',
          'rating': 5,
          'submitted_at': '2026-09-20T12:00:00Z',
          'updated_at': '2026-09-20T12:01:00Z',
        }),
        200,
      );
    }, apiUrl: 'https://api.example/tutor-staging-api');

    expect(await repository.fetchRating('media-1'), isNull);
    expect((await repository.rate('media-1', 5)).rating, 5);
    expect(requests.map((request) => request.method), ['GET', 'PUT']);
  });

  test('GET 404 é sem avaliação; 403 e 409 preservam causa', () async {
    final absent = _repository((_) async => http.Response('{}', 404));
    expect(await absent.fetchRating('media-1'), isNull);

    final noEnrollment = _repository((_) async => http.Response('{}', 403));
    await expectLater(
      noEnrollment.rate('media-1', 3),
      throwsA(
        isA<MediaRepositoryException>().having(
          (error) => error.issue,
          'issue',
          MediaRepositoryIssue.activeEnrollmentRequired,
        ),
      ),
    );

    final notCompleted = _repository((_) async => http.Response('{}', 409));
    await expectLater(
      notCompleted.rate('media-1', 5),
      throwsA(
        isA<MediaRepositoryException>().having(
          (error) => error.issue,
          'issue',
          MediaRepositoryIssue.qualifiedCompletionRequired,
        ),
      ),
    );
  });
}

MediaRepository _repository(
  Future<http.Response> Function(http.Request request) handler, {
  bool signedIn = true,
  String apiUrl = 'https://api.example',
}) {
  final auth = AuthRepository(
    apiUrl: apiUrl,
    client: MockClient((_) async => http.Response('{}', 500)),
    tokenStore: _TokenStore(
      signedIn
          ? const AuthTokens(accessToken: 'access', refreshToken: 'refresh')
          : null,
    ),
  );
  return MediaRepository(
    apiUrl: apiUrl,
    authRepository: auth,
    client: MockClient(handler),
  );
}

MediaItem _restrictedMedia() => MediaItem.fromJson({
  'id': 'media-1',
  'institution_id': 'inst-1',
  'program_id': 'program-1',
  'course_id': 'course-1',
  'module_id': 'module-1',
  'creator_user_id': 'creator-1',
  'title': 'Vídeo protegido',
  'description': '',
  'competency_id': 'competency-1',
  'provider': 'youtube',
  'playback_url': null,
  'duration_seconds': 120,
  'captions': const [],
  'visibility': 'enrolled',
  'offline_policy': 'forbidden',
  'status': 'published',
  'followup_activity_id': 'quiz-1',
  'published_at': '2026-09-20T12:00:00Z',
});
