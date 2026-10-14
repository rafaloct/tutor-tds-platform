@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter_test/flutter_test.dart';
import 'package:cartilhas_app/services/chatwoot_web_impl.dart';

Object? evaluate(String source) =>
    globalContext.callMethod<JSAny?>('eval'.toJS, source.toJS)?.dartify();

Future<void> loaded() async {
  for (var i = 0; i < 100; i++) {
    if (evaluate(
          '!!(window.__tdsSupportHost && __tdsSupportHost.frame.contentWindow.testScript)',
        ) ==
        true) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Isolated SDK document did not load.');
}

Future<void> turn() => Future<void>.delayed(const Duration(milliseconds: 20));
void status(String value) {
  evaluate(
    "window.dispatchEvent(new MessageEvent('message',{source:__tdsSupportHost.frame.contentWindow,origin:location.origin,data:{kind:'tds-support-status',session:__tdsSupportHost.session,status:'$value'}}));",
  );
}

void main() {
  setUp(() {
    evaluate(r'''
      window.testCalls=[];
      window.suppressOpened=false;
      window.savedCreateElement=document.createElement;
      document.createElement=function(tag) {
        var element=savedCreateElement.call(document,tag);
        if(tag!=="iframe") return element;
        var descriptor=Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype,"srcdoc");
        Object.defineProperty(element,"srcdoc",{set:function(html) {
          var stub="window.chatwootSDK={run:function(config){if(window.$chatwoot)return;parent.testCalls.push(['run',config.baseUrl,config.websiteToken]);window.$chatwoot={setUser:function(id,fields){parent.testCalls.push(['user',id,fields]);},setCustomAttributes:function(){},toggle:function(state){parent.testCalls.push(['toggle',state]);if(state==='open'&&!parent.suppressOpened)window.dispatchEvent(new Event('chatwoot:opened'));},reset:function(){parent.testCalls.push(['reset']);}};window.dispatchEvent(new Event('chatwoot:ready'));}};";
          html=html.replace("<script>","<script>"+stub);
          html=html.replace("document.head.appendChild(script);","window.testScript=script;");
          descriptor.set.call(element,html);
        }});
        return element;
      };
    ''');
  });
  tearDown(() {
    chatwootClose();
    evaluate('document.createElement=savedCreateElement;');
  });

  test(
    'token/base rotation creates a fresh SDK realm; only latest account opens',
    () async {
      final first = chatwootOpen(
        'https://chat.example.org',
        'token_a',
        'account-a',
        'A',
        '',
      );
      await loaded();
      evaluate(
        'window.oldFrame=__tdsSupportHost.frame;window.oldWindow=oldFrame.contentWindow;',
      );
      final second = chatwootOpen(
        'https://other.example.org/support',
        'token_b',
        'account-b',
        'João "TDS"\n</script>',
        '',
        identifierHash: 'signature-b',
      );
      await loaded();
      expect(evaluate('oldFrame.isConnected'), false);
      evaluate(
        "window.dispatchEvent(new MessageEvent('message',{source:oldWindow,origin:location.origin,data:{kind:'tds-support-status',session:$first,status:'ready'}}));",
      );
      expect(evaluate('testCalls.length'), 0);
      evaluate('__tdsSupportHost.frame.contentWindow.testScript.onload();');
      await turn();
      expect(evaluate('testCalls[0][1]'), 'https://other.example.org/support');
      expect(evaluate('testCalls[0][2]'), 'token_b');
      expect(evaluate('testCalls[1][1]'), 'account-b');
      expect(evaluate('testCalls[1][2].name'), 'João "TDS"\n</script>');
      expect(evaluate('testCalls[1][2].identifier_hash'), 'signature-b');
      expect(evaluate('testCalls[2][1]'), 'open');
      chatwootClose(first);
      expect(chatwootSessionCurrent(second), true);
      expect(evaluate('__tdsSupportHost.frame.isConnected'), true);
    },
  );
  test(
    'closing before load and foreign ready cannot resurrect a disposed host',
    () async {
      final lease = chatwootOpen(
        'https://chat.example.org',
        'token_a',
        'account-a',
        'A',
        '',
      );
      await loaded();
      evaluate('window.oldWindow=__tdsSupportHost.frame.contentWindow;');
      chatwootClose(lease);
      evaluate(
        "window.dispatchEvent(new MessageEvent('message',{source:oldWindow,origin:location.origin,data:{kind:'tds-support-status',session:$lease,status:'ready'}}));",
      );
      expect(evaluate('testCalls.length'), 0);
      expect(evaluate('window.__tdsSupportHost'), null);
    },
  );
  test(
    'script failure closes its context and retry can initialize another SDK',
    () async {
      var failures = 0;
      chatwootOpen(
        'https://chat.example.org',
        'token_a',
        'account-a',
        'A',
        '',
        onError: () => failures++,
      );
      await loaded();
      evaluate('__tdsSupportHost.frame.contentWindow.testScript.onerror();');
      await turn();
      expect(failures, 1);
      expect(evaluate('window.__tdsSupportHost'), null);
      chatwootOpen('https://chat.example.org', 'token_b', 'account-b', 'B', '');
      await loaded();
      evaluate('__tdsSupportHost.frame.contentWindow.testScript.onload();');
      await turn();
      expect(evaluate('testCalls[0][2]'), 'token_b');
      expect(evaluate('testCalls[1][1]'), 'account-b');
    },
  );
  test('changed auth session before ready sends no identity or open', () async {
    var current = true;
    chatwootOpen(
      'https://chat.example.org',
      'token_a',
      'account-a',
      'A',
      '',
      canIdentify: () => current,
    );
    await loaded();
    current = false;
    evaluate('__tdsSupportHost.frame.contentWindow.testScript.onload();');
    await turn();
    expect(evaluate("testCalls.filter(x=>x[0]==='user').length"), 0);
    expect(
      evaluate("testCalls.filter(x=>x[0]==='toggle'&&x[1]==='open').length"),
      0,
    );
    expect(evaluate('window.__tdsSupportHost'), null);
  });
  test(
    'SDK identity/contact error after opened is handled without logging details',
    () async {
      var failures = 0;
      chatwootOpen(
        'https://chat.example.org',
        'token_a',
        'account-a',
        'A',
        '',
        onError: () => failures++,
      );
      await loaded();
      evaluate('__tdsSupportHost.frame.contentWindow.testScript.onload();');
      await turn();
      expect(evaluate('testCalls[2][1]'), 'open');
      evaluate(
        "__tdsSupportHost.frame.contentWindow.dispatchEvent(new Event('chatwoot:error'));",
      );
      await turn();
      expect(failures, 1);
      expect(evaluate('window.__tdsSupportHost'), null);
    },
  );
  test('foreign-window and wrong-origin messages are ignored', () async {
    chatwootOpen('https://chat.example.org', 'token_a', 'account-a', 'A', '');
    await loaded();
    evaluate(
      "window.dispatchEvent(new MessageEvent('message',{source:window,origin:location.origin,data:{kind:'tds-support-status',session:__tdsSupportHost.session,status:'ready'}}));",
    );
    evaluate(
      "window.dispatchEvent(new MessageEvent('message',{source:__tdsSupportHost.frame.contentWindow,origin:'https://foreign.example.org',data:{kind:'tds-support-status',session:__tdsSupportHost.session,status:'ready'}}));",
    );
    expect(evaluate('testCalls.length'), 0);
  });
  test('missing ready times out without reporting opened', () async {
    var failures = 0;
    chatwootOpen(
      'https://chat.example.org',
      'token_a',
      'account-a',
      'A',
      '',
      loadTimeout: const Duration(milliseconds: 80),
      onError: () => failures++,
    );
    await loaded();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(failures, 1);
    expect(evaluate('window.__tdsSupportHost'), null);
  });
  test(
    'ready and toggle without SDK opened acknowledgement do not report success',
    () async {
      var opened = 0, failures = 0;
      evaluate('window.suppressOpened=true;');
      chatwootOpen(
        'https://chat.example.org',
        'token_a',
        'account-a',
        'A',
        '',
        loadTimeout: const Duration(milliseconds: 300),
        onOpened: () => opened++,
        onError: () => failures++,
      );
      await loaded();
      evaluate('__tdsSupportHost.frame.contentWindow.testScript.onload();');
      await turn();
      expect(
        evaluate("testCalls.filter(x=>x[0]==='toggle'&&x[1]==='open').length"),
        1,
      );
      expect(opened, 0);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(opened, 0);
      expect(failures, 1);
      expect(evaluate('window.__tdsSupportHost'), null);
    },
  );
  test('reservation blocks a late opening from an older screen', () async {
    final old = chatwootReserve();
    final current = chatwootReserve();
    chatwootOpen(
      'https://chat.example.org',
      'token_a',
      'account-a',
      'A',
      '',
      lease: old,
    );
    expect(evaluate('window.__tdsSupportHost'), null);
    chatwootOpen(
      'https://chat.example.org',
      'token_b',
      'account-b',
      'B',
      '',
      lease: current,
    );
    await loaded();
    evaluate('__tdsSupportHost.frame.contentWindow.testScript.onload();');
    await turn();
    expect(evaluate('testCalls[1][1]'), 'account-b');
  });
}
