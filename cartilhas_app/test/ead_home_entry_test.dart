import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/presentation/ead_catalog_screen.dart';
import 'package:cartilhas_app/models/cartilha.dart';
import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a Home prioriza o site EAD sem remover as cartilhas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cartilha = Cartilha(
      id: 'saf',
      title: 'Cartilha SAF instalada',
      author: 'TDS',
      sections: [
        Section(
          id: 'introducao',
          title: 'Introdução',
          messages: [Message(type: 'bot', content: 'Bem-vindo')],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          courseLoader: () async => [cartilha],
          eadCatalogLoader: () async => const [
            EadCourse(
              id: 1474,
              slug: 'automacoes-celular',
              title: 'Automações EAD',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cursos atualizados no EAD'), findsOneWidget);
    expect(find.text('Cartilha SAF instalada'), findsOneWidget);
    await tester.tap(find.text('Cursos atualizados no EAD'));
    await tester.pumpAndSettle();
    expect(find.byType(EadCatalogScreen), findsOneWidget);
    expect(find.text('Automações EAD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
