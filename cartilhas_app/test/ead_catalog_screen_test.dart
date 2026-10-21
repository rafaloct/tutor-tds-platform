import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/presentation/ead_catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows published courses and opens only canonical EAD URLs', (
    tester,
  ) async {
    viewport(tester);
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: EadCatalogScreen(
          courseLoader: () async => const [
            EadCourse(
              id: 1474,
              slug: 'automacoes-celular',
              title: 'Automações',
            ),
            EadCourse(
              id: 614,
              slug: 'inteligencia-artificial-e-inclusao-digital',
              title: 'IA e Inclusão',
            ),
          ],
          openCourse: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ofertas publicadas: 2'), findsOneWidget);
    expect(find.text('Automações'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ead-course-1474')));
    await tester.pump();
    expect(opened!.scheme, 'https');
    expect(opened!.host, 'ead.ipexdesenvolvimento.cloud');
    expect(opened!.path, '/courses/automacoes-celular/');
    expect(opened!.queryParameters['utm_source'], 'tutor_tds_app');
    expect(opened!.queryParameters['utm_campaign'], 'ead_catalog');
    expect(opened!.queryParameters['utm_content'], 'course_1474');
    expect(tester.takeException(), isNull);
  });

  testWidgets('inscrição abre o cadastro WordPress do curso sem CPF no link', (
    tester,
  ) async {
    viewport(tester);
    Uri? target;
    await tester.pumpWidget(
      MaterialApp(
        home: EadCatalogScreen(
          courseLoader: () async => const [
            EadCourse(
              id: 1298,
              slug: 'agricultura-sustentavel',
              title: 'Agricultura Sustentável',
            ),
          ],
          openRegistration: (uri) async {
            target = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('ead-register-1298'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(target, isNotNull);
    expect(target!.path, '/cadastro/');
    expect(target!.queryParameters['tds_curso'], '1298');
    expect(target!.queryParameters['utm_source'], 'tutor_tds_app');
    expect(target!.queryParameters['utm_campaign'], 'ead_signup');
    expect(target.toString(), isNot(contains('cpf')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('network failure keeps a useful retry state', (tester) async {
    viewport(tester);
    var online = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EadCatalogScreen(
          courseLoader: () async {
            if (!online) throw const EadCatalogException('sem rede');
            return const [EadCourse(id: 1356, slug: 'saf', title: 'SAF')];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    online = true;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('SAF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('broken browser handoff reports an accessible message', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EadCatalogScreen(
          courseLoader: () async => const [
            EadCourse(id: 1356, slug: 'saf', title: 'SAF'),
          ],
          openCourse: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ead-course-1356')));
    await tester.pump();
    expect(
      find.textContaining('Não foi possível abrir o curso'),
      findsOneWidget,
    );
  });

  testWidgets('empty publication is not replaced by stale local courses', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: EadCatalogScreen(courseLoader: () async => const [])),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhuma oferta publicada'), findsOneWidget);
  });
}
