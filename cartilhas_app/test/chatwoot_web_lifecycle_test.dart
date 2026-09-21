@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter_test/flutter_test.dart';
import 'package:cartilhas_app/services/chatwoot_web_impl.dart';

Object? evaluate(String source) =>
    globalContext.callMethod<JSAny?>('eval'.toJS, source.toJS)?.dartify();

void main() {
  test('late ready stays closed; reopen identifies latest account before open', () {
    evaluate(r'''
      window.testCalls = [];
      window.testScript = {};
      window.savedCreateElement = document.createElement;
      window.savedGetElements = document.getElementsByTagName;
      document.createElement = () => window.testScript;
      document.getElementsByTagName = () => [{parentNode: {insertBefore: () => {}}}];
      window.chatwootSDK = {run: () => {
        window.$chatwoot = {
          setUser: (id, fields) => testCalls.push(['user', id, fields]),
          setCustomAttributes: () => {},
          toggle: state => testCalls.push(['toggle', state]),
          reset: () => testCalls.push(['reset'])
        };
        window.dispatchEvent(new Event('chatwoot:ready'));
      }};
    ''');
    try {
      chatwootOpen('https://unused.invalid', 'fake', 'account-a', 'A', '');
    } finally {
      evaluate('document.createElement = savedCreateElement; document.getElementsByTagName = savedGetElements;');
    }
    chatwootClose();
    evaluate('testScript.onload();');
    expect(evaluate('testCalls.length'), 0);

    const name = 'João "TDS"\n</script>';
    chatwootOpen('https://unused.invalid', 'fake', 'account-b', name, '', identifierHash: 'signature-b');
    expect(evaluate('testCalls[0][1]'), 'account-b');
    expect(evaluate('testCalls[0][2].name'), name);
    expect(evaluate('testCalls[0][2].identifier_hash'), 'signature-b');
    expect(evaluate('testCalls[1][1]'), 'open');
    chatwootClose();
    expect(evaluate('testCalls[2][1]'), 'close');
    expect(evaluate('testCalls[3][0]'), 'reset');
    evaluate("window.dispatchEvent(new Event('chatwoot:ready'));");
    expect(evaluate('testCalls.length'), 4);
  });
}
