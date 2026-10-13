import 'dart:async';
import 'dart:convert';

import 'package:cartilhas_app/features/support/chatwoot_config.dart';
import 'package:cartilhas_app/features/support/chatwoot_config_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'fresh public fetch stays CORS-safelisted and observes token rotation',
    () async {
      var token = 'token_a';
      var base = 'https://chat.example.org/chat/';
      var calls = 0;
      final repository = HttpChatwootConfigRepository(
        apiUrl: 'https://api.example.org/tutor-api',
        client: MockClient((request) async {
          calls++;
          expect(
            request.url.toString(),
            'https://api.example.org/tutor-api/support/config',
          );
          expect(request.headers['Accept'], 'application/json');
          // API CORS permits no Cache-Control request header. Public support
          // must work without preflight, while its response remains no-store.
          expect(
            request.headers.keys.map((key) => key.toLowerCase()),
            everyElement(isIn(['accept', 'accept-language', 'content-language'])),
          );
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response(
            jsonEncode({'base_url': base, 'website_token': token}),
            200,
            headers: {'cache-control': 'no-store'},
          );
        }),
      );
      addTearDown(repository.dispose);
      final first = await repository.fetch();
      expect(first.baseUrl, 'https://chat.example.org/chat');
      expect(first.websiteToken, 'token_a');
      token = 'token_b';
      base = 'https://other.example.org';
      final second = await repository.fetch();
      expect(second.websiteToken, 'token_b');
      expect(second.baseUrl, 'https://other.example.org');
      expect(calls, 2);
    },
  );

  for (final value in [
    null,
    [],
    {},
    {'base_url': 'https://chat.example.org'},
    {'base_url': 4, 'website_token': 'token_a'},
    {'base_url': 'https://chat.example.org', 'website_token': 4},
    {
      'base_url': 'https://chat.example.org',
      'website_token': 'token_a',
      'identity_mode': 'unsigned',
    },
  ]) {
    test('rejects noncontract JSON: $value', () {
      expect(() => ChatwootConfig.fromJson(value), throwsFormatException);
    });
  }
  for (final base in [
    'http://chat.example.org',
    'https://user:password@chat.example.org',
    'https://@chat.example.org',
    'https://chat.example.org?',
    'https://chat.example.org#',
    'https://chat.example.org/?token=x',
    'https://chat.example.org/#x',
    'https://chat.example.org/unsafe path',
    'https://chat.example.org/a/../b',
    'https://chat.example.org/a/./b',
    'https://chat.example.org/%2e%2e',
    'https://chat.example.org:0',
    'https://chat.example.org:',
    'https://localhost',
    'https://chat.local',
    'https://router.home.arpa',
    'https://127.0.0.1',
    'https://127.1',
    'https://2130706433',
    'https://0x7f000001',
    'https://10.2.3.4',
    'https://169.254.169.254',
    'https://100.64.0.1',
    'https://192.168.1.1',
    'https://224.0.0.1',
    'https://[::1]',
    'https://[fe80::1]',
    'https://[2001:db8::1]',
    'https://[2001:0db8::1]',
    'https://[2001:0000::1]',
    'https://[3fff::1]',
    'https://[::ffff:8.8.8.8]',
    'https://[2001:db8::8.8.8.8]',
    'https://[2001:4860::8.8.8.256]',
    'https://[2001:4860::08.8.8.8]',
    'https://[2001:4860::8.8.8]',
  ]) {
    test('rejects unsafe SDK base: $base', () {
      expect(
        () => ChatwootConfig(baseUrl: base, websiteToken: 'token_a'),
        throwsFormatException,
      );
    });
  }
  for (final token in [
    '',
    'short',
    'a' * 257,
    'token space',
    '</script>',
    'token+plus',
  ]) {
    test('rejects invalid website token: $token', () {
      expect(
        () => ChatwootConfig(
          baseUrl: 'https://chat.example.org',
          websiteToken: token,
        ),
        throwsFormatException,
      );
    });
  }
  for (final base in [
    'https://chat.example.org',
    'https://chat.example.org:8443/support-v1._~',
    'https://1.1.1.1',
    'https://[2606:4700:4700::1111]',
    'https://[2001:20::1]',
    'https://[2001:1::1]',
    'https://[2001:0001::2]',
    'https://[2001:4:112::1]',
    'https://[2001:4860::8.8.8.8]',
  ]) {
    test('accepts safe base: $base', () {
      expect(
        ChatwootConfig(
          baseUrl: base,
          websiteToken: 'token_ABC-123',
        ).websiteToken,
        'token_ABC-123',
      );
    });
  }
  for (final status in [200, 401, 404, 503]) {
    test(
      'invalid/unavailable response is not replaced by a previous config: $status',
      () async {
        var valid = true;
        final repository = HttpChatwootConfigRepository(
          apiUrl: 'https://api.example.org/tutor-api/',
          client: MockClient(
            (_) async => valid
                ? http.Response(
                    '{"base_url":"https://chat.example.org","website_token":"token_a"}',
                    200,
                  )
                : http.Response('not valid json', status),
          ),
        );
        addTearDown(repository.dispose);
        await repository.fetch();
        valid = false;
        await expectLater(
          repository.fetch(),
          throwsA(isA<ChatwootConfigUnavailable>()),
        );
      },
    );
  }
  test(
    'bounded timeout produces unavailable, without retaining a response',
    () async {
      final pending = Completer<http.Response>();
      final repository = HttpChatwootConfigRepository(
        apiUrl: 'https://api.example.org',
        timeout: const Duration(milliseconds: 10),
        client: MockClient((_) => pending.future),
      );
      addTearDown(repository.dispose);
      await expectLater(
        repository.fetch(),
        throwsA(isA<ChatwootConfigUnavailable>()),
      );
      pending.complete(http.Response('{}', 200));
    },
  );
}
