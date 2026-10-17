import 'package:cartilhas_app/features/auth/data/auth_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/data/ead_catalog_repository.dart';
import 'package:cartilhas_app/features/ead_catalog/presentation/ead_catalog_screen.dart';
import 'package:cartilhas_app/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('EAD público é acessível antes de preencher CPF ou WhatsApp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = AuthRepository(apiUrl: '');
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      Provider<AuthRepository>.value(
        value: repository,
        child: MaterialApp(
          home: WelcomeScreen(
            skipExistingUserRedirect: true,
            eadCatalogLoader: () async => const [
              EadCourse(
                id: 1474,
                slug: 'automacoes-celular',
                title: 'Automações com o Celular',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final explore = find.byKey(const ValueKey('ead-public-explore'));
    expect(explore, findsOneWidget);
    await tester.ensureVisible(explore);
    await tester.tap(explore);
    await tester.pumpAndSettle();
    expect(find.byType(EadCatalogScreen), findsOneWidget);
    expect(find.text('Automações com o Celular'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_name'), isNull);
    expect(prefs.getString('user_cpf'), isNull);
    expect(tester.takeException(), isNull);
  });
}
