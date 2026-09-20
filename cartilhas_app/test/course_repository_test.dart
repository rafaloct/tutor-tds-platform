import 'dart:convert';

import 'package:cartilhas_app/features/courses/data/course_repository.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Cartilha course(String id, String title) =>
      Cartilha(id: id, title: title, author: 'TDS', sections: const []);

  test('usa catálogo remoto e mantém ordenação', () async {
    final repository = CourseRepository(
      apiUrl: 'https://api.example/',
      httpGet: (uri) async {
        expect(uri.toString(), 'https://api.example/courses');
        return http.Response(
          jsonEncode({
            'courses': [
              course('b', 'Zootecnia').toJson(),
              course('a', 'Agricultura').toJson(),
            ],
          }),
          200,
        );
      },
      localLoader: () async => [course('local', 'Local')],
    );

    final courses = await repository.fetchAll();
    expect(courses.map((item) => item.id), ['a', 'b']);
  });

  test('usa cache remoto quando a API fica indisponível', () async {
    final first = CourseRepository(
      apiUrl: 'https://api.example',
      httpGet: (_) async => http.Response(
        jsonEncode([course('cache', 'Curso em cache').toJson()]),
        200,
      ),
      localLoader: () async => [course('local', 'Curso local')],
    );
    await first.fetchAll();

    final offline = CourseRepository(
      apiUrl: 'https://api.example',
      httpGet: (_) async => http.Response('offline', 503),
      localLoader: () async => [course('local', 'Curso local')],
    );

    expect((await offline.fetchAll()).single.id, 'cache');
  });

  test('usa assets locais quando endpoint não está configurado', () async {
    var networkCalled = false;
    final repository = CourseRepository(
      apiUrl: '',
      httpGet: (_) async {
        networkCalled = true;
        return http.Response('unexpected', 500);
      },
      localLoader: () async => [course('local', 'Curso local')],
    );

    expect((await repository.fetchAll()).single.id, 'local');
    expect(networkCalled, isFalse);
  });
}
