import 'dart:convert';
import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/auth/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'auth_repository_test.dart' show MemoryTokenStore, unverifiedToken;

void main() {
  for (final changeAccount in [false, true]) {
    test('support identity discards changed session: $changeAccount', () async {
      final store = MemoryTokenStore()
        ..value = AuthTokens(
          accessToken: unverifiedToken({'sub': 'owner-1'}),
          refreshToken: 'refresh',
        );
      final repo = AuthRepository(
        apiUrl: 'https://example.test/prefix',
        tokenStore: store,
        client: MockClient((request) async {
          expect(request.url.path, '/prefix/support/identity');
          expect(request.headers['Authorization'], startsWith('Bearer '));
          if (changeAccount) await store.clear();
          return http.Response(
            jsonEncode({
              'identifier': 'tds:owner-1',
              'identifier_hash': 'a' * 64,
            }),
            200,
          );
        }),
      );
      if (changeAccount) {
        await expectLater(
          repo.supportIdentity(),
          throwsA(isA<AuthException>()),
        );
      } else {
        expect((await repo.supportIdentity())['identifier'], 'tds:owner-1');
      }
      expect(store.writes, 0);
      repo.dispose();
    });
  }
}
