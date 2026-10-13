import 'package:cartilhas_app/features/support/chatwoot_config.dart';
import 'package:cartilhas_app/features/support/chatwoot_host_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'configuration literals are JSON encoded and identity waits for host authorization',
    () {
      final html = chatwootHostHtml(
        ChatwootConfig(
          baseUrl: 'https://chat.example.org/support',
          websiteToken: 'token_a',
        ),
      );
      expect(html, contains('var base = "https://chat.example.org/support"'));
      expect(html, contains('websiteToken:"token_a"'));
      expect(
        html.indexOf('chatwoot:ready'),
        lessThan(html.indexOf('window.chatwootSDK.run')),
      );
      expect(html, contains('script.onerror'));
      expect(html, contains('chatwoot:opened'));
      final identifyBody = html.substring(
        html.indexOf('window.__tdsSupportIdentify ='),
        html.indexOf('chatwoot:ready'),
      );
      expect(identifyBody, isNot(contains('signal("opened")')));
      expect(html, contains('TdsSupportStatus.postMessage'));
      expect(html.indexOf('setUser'), lessThan(html.indexOf('toggle("open")')));
      final readyBody = html.substring(
        html.indexOf('chatwoot:ready'),
        html.indexOf('chatwoot:closed'),
      );
      expect(readyBody, isNot(contains('setUser')));
    },
  );
  test(
    'identity script preserves text as data and cannot terminate HTML script',
    () {
      final script = chatwootIdentifyScript(
        id: 'id',
        name: 'João "TDS"\n</script>',
        phone: '',
        identifierHash: 'signature',
      );
      expect(script, contains(r'\u003c/script\u003e'));
      expect(script, isNot(contains('</script>')));
    },
  );
}
