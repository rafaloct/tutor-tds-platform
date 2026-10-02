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

  test('flag false ignora API e cache remoto', () async {
    var calls = 0;
    final repository = CourseRepository.forCatalog(
      apiUrl: 'https://api.example',
      remoteCatalogEnabled: false,
      httpGet: (_) async {
        calls++;
        return http.Response('unexpected', 200);
      },
      localLoader: () async => [course('local', 'Curso local')],
    );
    expect((await repository.fetchAll()).single.id, 'local');
    expect(calls, 0);
  });

  test('flag true consulta API sem autenticação', () async {
    final repository = CourseRepository.forCatalog(
      apiUrl: 'https://api.example',
      remoteCatalogEnabled: true,
      httpGet: (uri) async {
        expect(uri.toString(), 'https://api.example/courses');
        return http.Response(
          jsonEncode({
            'courses': [course('remote', 'Remoto').toJson()],
          }),
          200,
        );
      },
      localLoader: () async => [course('local', 'Local')],
    );
    expect((await repository.fetchAll()).single.id, 'remote');
  });

  test('flag true usa cache quando API falha', () async {
    await CourseRepository.forCatalog(
      apiUrl: 'https://api.example',
      remoteCatalogEnabled: true,
      httpGet: (_) async =>
          http.Response(jsonEncode([course('cached', 'Cache').toJson()]), 200),
    ).fetchAll();
    final repository = CourseRepository.forCatalog(
      apiUrl: 'https://api.example',
      remoteCatalogEnabled: true,
      httpGet: (_) async => http.Response('offline', 503),
      localLoader: () async => [course('local', 'Local')],
    );
    expect((await repository.fetchAll()).map((item) => item.id), ['cached']);
  });

  test('flag true sem cache recorre aos assets locais', () async {
    final repository = CourseRepository.forCatalog(
      apiUrl: 'https://api.example',
      remoteCatalogEnabled: true,
      httpGet: (_) async => http.Response('offline', 503),
      localLoader: () async => [course('local', 'Local')],
    );
    expect((await repository.fetchAll()).single.id, 'local');
  });

  test('catálogo remoto independe de LearningContext desligado', () async {
    const learningContextEnabled = bool.fromEnvironment(
      'LEARNING_CONTEXT_ENABLED',
    );
    expect(learningContextEnabled, isFalse);
    final repository = CourseRepository.forCatalog(
      apiUrl: 'https://api.example',
      remoteCatalogEnabled: true,
      httpGet: (_) async =>
          http.Response(jsonEncode([course('remote', 'Remoto').toJson()]), 200),
    );
    expect((await repository.fetchAll()).single.id, 'remote');
  });

  test('flag true respeita catálogo vazio mesmo com assets', () async {
    final repository = CourseRepository.forCatalog(
      apiUrl: 'https://api.example',
      remoteCatalogEnabled: true,
      httpGet: (_) async => http.Response('{"courses":[]}', 200),
      localLoader: () async => [course('local', 'Local')],
    );
    expect(await repository.fetchAll(), isEmpty);
  });

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

  for (final otherApi in [
    'https://staging.example/tutor-api',
    'https://api.example/staging-api',
  ]) {
    test('isola catálogos por API completa: $otherApi', () async {
      const firstApi = 'https://api.example/tutor-api';
      for (final entry in {firstApi: 'first', otherApi: 'second'}.entries) {
        final online = CourseRepository(
          apiUrl: entry.key,
          httpGet: (_) async => http.Response(
            jsonEncode([course(entry.value, 'Curso remoto').toJson()]),
            200,
          ),
        );
        expect((await online.fetchAll()).single.id, entry.value);
      }

      for (final entry in {firstApi: 'first', otherApi: 'second'}.entries) {
        final offline = CourseRepository(
          apiUrl: entry.key,
          httpGet: (_) async => http.Response('offline', 503),
          localLoader: () async => [course('local', 'Curso local')],
        );
        expect((await offline.fetchAll()).single.id, entry.value);
      }
    });
  }

  test(
    'normaliza espaços e barras finais sem perder o caminho da API',
    () async {
      final online = CourseRepository(
        apiUrl: '  https://api.example/tutor-api///  ',
        httpGet: (uri) async {
          expect(uri.toString(), 'https://api.example/tutor-api/courses');
          return http.Response(
            jsonEncode([course('remote', 'Curso remoto').toJson()]),
            200,
          );
        },
      );
      await online.fetchAll();

      for (final base in [
        'https://api.example/tutor-api',
        'https://api.example/tutor-api/',
        ' https://api.example/tutor-api// ',
      ]) {
        final offline = CourseRepository(
          apiUrl: base,
          httpGet: (uri) async {
            expect(uri.toString(), 'https://api.example/tutor-api/courses');
            return http.Response('offline', 503);
          },
          localLoader: () async => [course('local', 'Curso local')],
        );
        expect((await offline.fetchAll()).single.id, 'remote');
      }
    },
  );

  test('preserva cache legado sem atribuir sua origem a uma API', () async {
    const legacyKey = 'courses:remote_cache:v1';
    final legacy = jsonEncode([
      course('legacy', 'Origem desconhecida').toJson(),
    ]);
    SharedPreferences.setMockInitialValues({legacyKey: legacy});

    final offline = CourseRepository(
      apiUrl: 'https://api.example',
      httpGet: (_) async => http.Response('offline', 503),
      localLoader: () async => [course('local', 'Curso local')],
    );
    expect((await offline.fetchAll()).single.id, 'local');

    final online = CourseRepository(
      apiUrl: 'https://api.example',
      httpGet: (_) async => http.Response(
        jsonEncode([course('verified', 'Origem confirmada').toJson()]),
        200,
      ),
    );
    expect((await online.fetchAll()).single.id, 'verified');
    expect((await offline.fetchAll()).single.id, 'verified');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(legacyKey), legacy);
  });

  test(
    'catálogo vazio substitui somente o cache do próprio ambiente',
    () async {
      const firstApi = 'https://api.example/tutor-api';
      const secondApi = 'https://api.example/staging-api';
      for (final base in [firstApi, secondApi]) {
        await CourseRepository(
          apiUrl: base,
          httpGet: (_) async => http.Response(
            jsonEncode([course('published', 'Curso publicado').toJson()]),
            200,
          ),
        ).fetchAll();
      }
      final emptied = CourseRepository(
        apiUrl: secondApi,
        httpGet: (_) async => http.Response('{"courses":[]}', 200),
      );
      expect(await emptied.fetchAll(), isEmpty);

      Future<List<Cartilha>> offline(String base) => CourseRepository(
        apiUrl: base,
        httpGet: (_) async => http.Response('offline', 503),
        localLoader: () async => [course('local', 'Curso local')],
      ).fetchAll();
      expect((await offline(firstApi)).single.id, 'published');
      expect(await offline(secondApi), isEmpty);
    },
  );

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

  test(
    'catálogo vazio autorizado não restaura cursos removidos nem offline',
    () async {
      Future<List<Cartilha>> local() async => [course('old', 'Curso retirado')];
      final online = CourseRepository(
        apiUrl: 'https://api.example',
        httpGet: (_) async => http.Response('{"courses":[]}', 200),
        localLoader: local,
      );
      expect(await online.fetchAll(), isEmpty);
      final offline = CourseRepository(
        apiUrl: 'https://api.example',
        httpGet: (_) async => http.Response('offline', 503),
        localLoader: local,
      );
      expect(await offline.fetchAll(), isEmpty);
    },
  );

  test('resposta inválida não apaga o cache válido', () async {
    final online = CourseRepository(
      apiUrl: 'https://api.example',
      httpGet: (_) async => http.Response(
        jsonEncode({
          'courses': [course('valid', 'Curso').toJson()],
        }),
        200,
      ),
    );
    await online.fetchAll();
    final invalid = CourseRepository(
      apiUrl: 'https://api.example',
      httpGet: (_) async => http.Response('{"error":"invalid"}', 200),
    );
    expect((await invalid.fetchAll()).single.id, 'valid');
  });
}
