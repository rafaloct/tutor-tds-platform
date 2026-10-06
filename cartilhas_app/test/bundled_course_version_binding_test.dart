import 'dart:convert';
import 'dart:io';

import 'package:cartilhas_app/models/cartilha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bindings = <String, String>{
    'agricultura-sustentavel': '0674ba94-afc2-5953-a5a0-78177b26179a',
    'atendimento-cliente': 'e999578b-ad08-5ec5-85d9-a73884b08384',
    'audiovisual': 'd1dce262-153d-5b7d-92ae-af2b30b0f6d8',
    'cooperativismo': '389184fc-822c-541f-aff0-bd527c9f1b71',
    'economia-lar': '02f0ea37-d7e1-569b-adbb-0b85db2437af',
    'educacao-financeira': '1fc331d9-3a76-5eb3-996a-9161ba0c995a',
    'ia-cartilha': 'd496856d-6bf3-5f8a-92a3-f292cca92ed5',
    'saf': '9350c62e-14fd-5340-9408-c73a5b36b399',
    'sim-sima': '59a3021e-be92-5e3e-ad63-5427bbb49374',
  };

  test('bundled catalog binds every legacy course to canonical v1', () {
    for (final entry in bindings.entries) {
      final source = File(
        'assets/data/lessons/${entry.key}.json',
      ).readAsStringSync();
      final payload = jsonDecode(source) as Map<String, dynamic>;
      final course = Cartilha.fromJson(payload);

      expect(course.id, entry.key);
      expect(course.courseVersionId, entry.value);
      expect(course.versionNumber, 1);
      expect(course.legacyProgressCompatible, isTrue);
    }
  });
}
