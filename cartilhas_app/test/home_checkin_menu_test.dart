import 'package:cartilhas_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Mais opções'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'menu sem sessão autenticada não expõe Registrar presença nem Gestão',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Sem AuthRepository no contexto (e sem TUTOR_API_URL), _hasSession
      // permanece falso: presença e gestão ficam fora do menu.
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(courseLoader: () async => [])),
      );
      await tester.pumpAndSettle();

      await _openMenu(tester);

      expect(find.text('Registrar presença'), findsNothing);
      expect(find.text('Gestão'), findsNothing);
      expect(find.text('Como usar'), findsOneWidget);
      expect(find.text('Sobre o Programa'), findsOneWidget);
    },
  );

  testWidgets(
    'aluno autenticado vê Registrar presença sem ganhar Gestão',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            courseLoader: () async => [],
            sessionProbe: () async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openMenu(tester);

      expect(find.text('Registrar presença'), findsOneWidget);
      expect(find.text('Gestão'), findsNothing);
    },
  );
}
