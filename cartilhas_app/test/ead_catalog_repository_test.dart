import 'dart:convert';

import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

Map<String, Object?> course(
  int id,
  String slug,
  String title, {
  String status = 'publish',
}) => {
  'id': id,
  'slug': slug,
  'title': {'rendered': title},
  'status': status,
};

http.Response ok(List<Map<String, Object?>> data, {int pages = 1}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(data)),
      200,
      headers: {
        'x-wp-totalpages': pages.toString(),
        'content-type': 'application/json; charset=utf-8',
      },
    );

void main() {
  test(
    'reads the real WordPress public contract, without login or PII',
    () async {
      Uri? requested;
      final repo = EadCatalogRepository(
        httpGet: (url) async {
          requested = url;
          return ok([
            course(1474, 'automacoes-celular', 'Automações &amp; Celular'),
            course(
              614,
              'inteligencia-artificial-e-inclusao-digital',
              'IA e Inclusão',
            ),
          ]);
        },
      );
      final courses = await repo.fetchPublished();
      expect(courses, hasLength(2));
      expect(courses.first.title, 'Automações & Celular');
      expect(requested!.scheme, 'https');
      expect(requested!.host, 'ead.ipexdesenvolvimento.cloud');
      expect(requested!.path, '/wp-json/wp/v2/lp_course');
      expect(requested!.queryParameters['per_page'], '100');
      expect(requested!.queryParameters['_fields'], 'id,slug,title,status');
      expect(
        courses.first.url.toString(),
        'https://ead.ipexdesenvolvimento.cloud/courses/automacoes-celular/',
      );
      expect(requested!.queryParameters, isNot(contains('cpf')));
    },
  );

  test('filters drafts and accepts an empty published snapshot', () async {
    final repo = EadCatalogRepository(
      httpGet: (_) async =>
          ok([course(9, 'interno', 'Rascunho', status: 'draft')]),
    );
    expect(await repo.fetchPublished(), isEmpty);
  });

  test('catalog pagination does not silently discard courses', () async {
    final requests = <int>[];
    final repo = EadCatalogRepository(
      httpGet: (uri) async {
        final page = int.parse(uri.queryParameters['page']!);
        requests.add(page);
        return page == 1
            ? ok([
                course(1298, 'agricultura-sustentavel', 'Agricultura'),
              ], pages: 2)
            : ok([course(1474, 'automacoes-celular', 'Automações')], pages: 2);
      },
    );
    expect((await repo.fetchPublished()).length, 2);
    expect(requests, [1, 2]);
  });

  test(
    'rejects fake slugs and never constructs malicious navigation',
    () async {
      final repo = EadCatalogRepository(
        httpGet: (_) async => ok([course(12, '../../redirect', 'Ataque')]),
      );
      await expectLater(
        repo.fetchPublished(),
        throwsA(isA<EadCatalogException>()),
      );
    },
  );

  test('rejects duplicate identities across pages', () async {
    final repo = EadCatalogRepository(
      httpGet: (uri) async {
        return ok([course(614, 'ia-cartilha', 'IA')], pages: 2);
      },
    );
    await expectLater(
      repo.fetchPublished(),
      throwsA(isA<EadCatalogException>()),
    );
  });

  test('server 503 and malformed payload fail visibly', () async {
    final down = EadCatalogRepository(
      httpGet: (_) async => http.Response('', 503),
    );
    await expectLater(
      down.fetchPublished(),
      throwsA(isA<EadCatalogException>()),
    );
    final malformed = EadCatalogRepository(
      httpGet: (_) async => http.Response('{"courses":[]}', 200),
    );
    await expectLater(
      malformed.fetchPublished(),
      throwsA(isA<EadCatalogException>()),
    );
  });

  test(
    'excessive pagination fails instead of publishing partial catalog',
    () async {
      final repo = EadCatalogRepository(httpGet: (_) async => ok([], pages: 8));
      await expectLater(
        repo.fetchPublished(),
        throwsA(isA<EadCatalogException>()),
      );
    },
  );
}
