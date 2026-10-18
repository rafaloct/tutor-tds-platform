import 'package:cartilhas_app/features/ead_catalog/qa/private_editorial_qa_bridge.dart';
import 'package:cartilhas_app/features/ead_catalog/learning_path/ead_editorial_bridge_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QA bridge disabled without isolated debug run defines', () {
    if (!PrivateEditorialQaBridge.enabled) {
      expect(PrivateEditorialQaBridge.curriculumUri(12), isNull);
      expect(PrivateEditorialQaBridge.lessonUri(12, 13), isNull);
      expect(EadEditorialBridgeRepository.curriculumUrl(12).scheme, 'https');
    }
  });
  test('isolated QA only redirects course 12, lesson 13 via loopback', () {
    if (PrivateEditorialQaBridge.enabled) {
      final uri = PrivateEditorialQaBridge.curriculumUri(12)!;
      expect(uri.scheme, 'http');
      expect(uri.host, '127.0.0.1');
      expect(uri.port, 18731);
      expect(
        uri.queryParameters['rest_route'],
        '/tds-learning/v1/courses/12/curriculum',
      );
      expect(
        PrivateEditorialQaBridge.headers['Host'],
        'tds-learning-qa-wp-20261017',
      );
      expect(PrivateEditorialQaBridge.curriculumUri(1356), isNull);
      expect(PrivateEditorialQaBridge.lessonUri(12, 99), isNull);
      expect(EadEditorialBridgeRepository.curriculumUrl(1356).scheme, 'https');
    } else {
      expect(PrivateEditorialQaBridge.lessonUri(12, 13), isNull);
    }
  });
}
