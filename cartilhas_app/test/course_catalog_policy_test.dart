import 'dart:convert';

import 'package:cartilhas_app/features/courses/data/course_repository.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _api = 'https://catalog.example/tutor-api';
String _key(String api) =>
    'courses:remote_cache:v2:${Uri.encodeComponent(api)}';
Cartilha _course(String id) =>
    Cartilha(id: id, title: 'Curso $id', author: 'TDS', sections: const []);
String _body(List<String> ids) =>
    jsonEncode({'courses': ids.map((id) => _course(id).toJson()).toList()});
CourseRepository _repository(CourseHttpGet request, {String api = _api}) =>
    CourseRepository.forCatalog(
      apiUrl: api,
      remoteCatalogEnabled: true,
      httpGet: request,
      localLoader: () async => [_course('retirado'), _course('embarcado')],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final empty in ['[]', '{"courses":[]}']) {
    test('empty $empty survives repository and preferences restart', () async {
      await _repository(
        (_) async => http.Response(_body(['retirado']), 200),
      ).fetchAll();
      expect(
        await _repository((_) async => http.Response(empty, 200)).fetchAll(),
        isEmpty,
      );
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key(_api));
      expect(jsonDecode(saved!), isEmpty);
      SharedPreferences.setMockInitialValues({_key(_api): saved});
      expect(
        await _repository((_) async => throw Exception('offline')).fetchAll(),
        isEmpty,
      );
    });
  }

  test(
    'partial withdrawal never unions bundled or old cached courses',
    () async {
      var body = _body(['retirado', 'mantido']);
      var offline = false;
      final repository = _repository(
        (_) async =>
            offline ? http.Response('offline', 503) : http.Response(body, 200),
      );
      expect((await repository.fetchAll()).map((c) => c.id), [
        'mantido',
        'retirado',
      ]);
      body = _body(['mantido']);
      expect((await repository.fetchAll()).single.id, 'mantido');
      offline = true;
      expect((await repository.fetchAll()).single.id, 'mantido');
      expect(
        (await _repository(
          (_) async => http.Response('', 503),
        ).fetchAll()).single.id,
        'mantido',
      );
    },
  );

  test(
    'assets bootstrap only before first successful remote snapshot',
    () async {
      var status = 503;
      final repository = _repository(
        (_) async => http.Response('{"courses":[]}', status),
      );
      expect(await repository.fetchAll(), hasLength(2));
      status = 200;
      expect(await repository.fetchAll(), isEmpty);
      status = 503;
      expect(await repository.fetchAll(), isEmpty);
    },
  );

  final malformed = <String, String>{
    'broken json': '{',
    'missing courses': '{}',
    'non-list courses': '{"courses":null}',
    'null entry': '{"courses":[null]}',
    'scalar entry': '{"courses":[42]}',
    'missing required fields': '{"courses":[{}]}',
    'empty title': jsonEncode({
      'courses': [_course('bad').toJson()..['title'] = ''],
    }),
    'blank id': jsonEncode({
      'courses': [_course('bad').toJson()..['id'] = ' '],
    }),
    'mixed valid and invalid': jsonEncode({
      'courses': [_course('new').toJson(), null],
    }),
  };
  for (final entry in malformed.entries) {
    test('${entry.key} keeps the entire last valid remote snapshot', () async {
      await _repository(
        (_) async => http.Response(_body(['mantido']), 200),
      ).fetchAll();
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(_key(_api));
      final result = await _repository(
        (_) async => http.Response(entry.value, 200),
      ).fetchAll();
      expect(result.single.id, 'mantido');
      expect(prefs.getString(_key(_api)), before);
    });
  }

  for (final status in [401, 403, 500]) {
    test('HTTP $status is failure rather than empty publication', () async {
      await _repository(
        (_) async => http.Response(_body(['mantido']), 200),
      ).fetchAll();
      final result = await _repository(
        (_) async => http.Response('{"courses":[]}', status),
      ).fetchAll();
      expect(result.single.id, 'mantido');
    });
  }

  test('empty cache is isolated by complete API URL', () async {
    const other = 'https://catalog.example/other-api';
    await _repository((_) async => http.Response('[]', 200)).fetchAll();
    await _repository(
      (_) async => http.Response(_body(['outro']), 200),
      api: other,
    ).fetchAll();
    expect(
      await _repository((_) async => http.Response('', 503)).fetchAll(),
      isEmpty,
    );
    expect(
      (await _repository(
        (_) async => http.Response('', 503),
        api: other,
      ).fetchAll()).single.id,
      'outro',
    );
  });

  test(
    'known in-memory empty snapshot takes priority over stale disk',
    () async {
      var offline = false;
      final repository = _repository(
        (_) async => http.Response(offline ? '' : '[]', offline ? 503 : 200),
      );
      expect(await repository.fetchAll(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(_api), _body(['retirado']));
      offline = true;
      expect(await repository.fetchAll(), isEmpty);
    },
  );

  test('flag false ignores both empty cache and remote endpoint', () async {
    SharedPreferences.setMockInitialValues({_key(_api): '[]'});
    var calls = 0;
    final repository = CourseRepository.forCatalog(
      apiUrl: _api,
      remoteCatalogEnabled: false,
      httpGet: (_) async {
        calls++;
        return http.Response('[]', 200);
      },
      localLoader: () async => [_course('local')],
    );
    expect((await repository.fetchAll()).single.id, 'local');
    expect(calls, 0);
  });

  test('unreadable cache is not an authoritative empty snapshot', () async {
    SharedPreferences.setMockInitialValues({_key(_api): '{broken'});
    expect(
      await _repository((_) async => http.Response('', 503)).fetchAll(),
      hasLength(2),
    );
  });

  testWidgets(
    'real repository removes Home cards and stays empty after recreation',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var body = _body(['retirado']);
      final repository = _repository((_) async => http.Response(body, 200));
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(courseLoader: repository.fetchAll)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Curso retirado'), findsWidgets);
      body = '{"courses":[]}';
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Atualizar catálogo'));
      await tester.pumpAndSettle();
      expect(find.text('Curso retirado'), findsNothing);
      expect(find.text('Nenhuma cartilha encontrada.'), findsOneWidget);
      final offline = _repository((_) async => http.Response('', 503));
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            key: const ValueKey('offline-recreated'),
            courseLoader: offline.fetchAll,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma cartilha encontrada.'), findsOneWidget);
      expect(find.text('Curso retirado'), findsNothing);
      expect(find.text('Curso embarcado'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
