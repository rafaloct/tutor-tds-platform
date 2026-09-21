import 'dart:convert';

import 'package:cartilhas_app/services/chatwoot_script_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves profile text without making it executable script', () {
    for (final value in [
      'João D\'Ávila "TDS"',
      'linha\nbarra\\fim',
      '"); window.unwanted = true; //',
      '</script><script>alert(1)</script>',
      'a\u2028b\u2029c & fim',
      '',
    ]) {
      final encoded = chatwootScriptValue(value);
      expect(jsonDecode(encoded), value);
      expect(encoded, isNot(contains('<')));
      expect(encoded, isNot(contains('>')));
      expect(encoded, isNot(contains('&')));
      expect(encoded, isNot(contains('\u2028')));
      expect(encoded, isNot(contains('\u2029')));
    }
  });
}
