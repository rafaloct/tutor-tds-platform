import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cartilhas_app/main.dart';
import 'package:cartilhas_app/screens/genui_assistant_screen.dart';
import 'package:cartilhas_app/services/anything_llm_service.dart';

// Grava dados de teste no SharedPreferences real do dispositivo
Future<void> _registerTestUser() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user_name', 'Aluno Teste');
  await prefs.setString('user_phone', '(63) 99999-0000');
  await prefs.setString('user_cpf', '123.456.789-00');
  await prefs.setBool('privacy_notice_seen_v1', true);
  await prefs.setBool('privacy_consent_v1', true);
}

Future<void> _clearUser() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ──────────────────────────────────────────
  // ETAPA 1 — Tela de Boas-vindas / Enrollment
  // ──────────────────────────────────────────
  group('Welcome Screen', () {
    setUp(_clearUser);

    testWidgets('[01] campos e botão Entrar visíveis', (tester) async {
      await tester.pumpWidget(const CartilhasApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Bem-vindo ao TDS'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Nome completo'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'WhatsApp'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'CPF'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('[02] validação — Entrar sem dados mostra erro', (
      tester,
    ) async {
      await tester.pumpWidget(const CartilhasApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Obrigatório'), findsAtLeastNWidgets(1));
    });

    testWidgets('[03] preenchimento completo navega para Home', (tester) async {
      await tester.pumpWidget(const CartilhasApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome completo'),
        'Aluno Teste',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'WhatsApp'),
        '63999990000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'CPF'),
        '12345678900',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      final enterButton = find.widgetWithText(ElevatedButton, 'Entrar');
      await tester.ensureVisible(enterButton);
      await tester.pumpAndSettle();
      await tester.tap(enterButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Aprenda no seu ritmo'), findsOneWidget);

      await tester.tap(find.text('Pular'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Tutor TDS'), findsOneWidget);
    });

    testWidgets('[04] usuário já cadastrado pula direto para Home', (
      tester,
    ) async {
      await _registerTestUser();

      await tester.pumpWidget(const CartilhasApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Não deve mostrar o formulário
      expect(find.text('Bem-vindo ao TDS'), findsNothing);
      expect(find.text('Tutor TDS'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────
  // ETAPA 2 — Home Screen
  // ──────────────────────────────────────────
  group('Home Screen', () {
    setUp(_registerTestUser);

    testWidgets('[05] lista de cartilhas carregada', (tester) async {
      await tester.pumpWidget(const CartilhasApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(Card), findsAtLeastNWidgets(1));
    });

    testWidgets('[06] ícone de Glossário presente', (tester) async {
      await tester.pumpWidget(const CartilhasApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byIcon(Icons.menu_book), findsOneWidget);
    });

    testWidgets('[07] ícone de cadastro (person_add) presente', (tester) async {
      await tester.pumpWidget(const CartilhasApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('[08] abre a central Estudar com IA', (tester) async {
      await tester.pumpWidget(const CartilhasApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('Estudar com IA'));
      await tester.pumpAndSettle();

      expect(find.text('Visão geral da IA'), findsOneWidget);
      expect(find.text('Chat com IA'), findsOneWidget);
      expect(find.text('Cartões de estudo'), findsOneWidget);
      expect(find.text('Quiz com IA'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Resumo com IA'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────
  // ETAPA 3 — Glossário
  // ──────────────────────────────────────────
  group('Glossário', () {
    setUp(_registerTestUser);

    testWidgets('[09] abre e mostra termos das cartilhas', (tester) async {
      await tester.pumpWidget(const CartilhasApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.byIcon(Icons.menu_book));
      await tester.pumpAndSettle();

      expect(find.text('Glossário TDS'), findsOneWidget);
      expect(find.text('Adubação Orgânica'), findsOneWidget);
    });

    testWidgets('[10] busca filtra termos corretamente', (tester) async {
      await tester.pumpWidget(const CartilhasApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.byIcon(Icons.menu_book));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'crédito');
      await tester.pumpAndSettle();

      expect(find.text('Crédito'), findsOneWidget);
      expect(find.text('Agroecologia'), findsNothing);
    });

    testWidgets('[11] Perguntar à IA abre tutor contextualizado', (
      tester,
    ) async {
      await tester.pumpWidget(const CartilhasApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.byIcon(Icons.menu_book));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perguntar à IA').first);
      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (find.byIcon(Icons.volume_up_outlined).evaluate().length >= 2) {
          break;
        }
      }

      expect(find.text('Geral'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsAtLeastNWidgets(2));
    });
  });

  // ──────────────────────────────────────────
  // ETAPA 4 — Tutor (GenUIAssistantScreen direto, sem rede)
  // ──────────────────────────────────────────
  group('Tutor', () {
    // Monta o screen diretamente sem passar pelo glossário para evitar
    // requisição HTTP pendente entre testes
    Widget tutorApp() => MultiProvider(
      providers: [Provider(create: (_) => AnythingLLMService(gatewayUrl: ''))],
      child: const MaterialApp(
        home: GenUIAssistantScreen(), // sem initialContext = sem HTTP
      ),
    );

    testWidgets('[12] widgets essenciais presentes (campo, send, mic)', (
      tester,
    ) async {
      await tester.pumpWidget(tutorApp());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);

      final hasMic = find.byIcon(Icons.mic_none).evaluate().isNotEmpty;
      final hasMicOff = find.byIcon(Icons.mic_off).evaluate().isNotEmpty;
      expect(
        hasMic || hasMicOff,
        isTrue,
        reason: 'Ícone de microfone (disponível ou indisponível) deve existir',
      );
    });

    testWidgets('[13] mensagem de boas-vindas do tutor aparece', (
      tester,
    ) async {
      await tester.pumpWidget(tutorApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('tutor'), findsAtLeastNWidgets(1));
    });

    testWidgets('[14] chip de modo "Geral" presente por padrão', (
      tester,
    ) async {
      await tester.pumpWidget(tutorApp());
      await tester.pumpAndSettle();

      expect(find.text('Geral'), findsOneWidget);
    });

    testWidgets(
      '[15] troca para modo Minha Realidade e aparece mensagem adaptativa',
      (tester) async {
        await tester.pumpWidget(tutorApp());
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(Chip, 'Geral'));
        await tester.pumpAndSettle();

        expect(find.text('Minha Realidade'), findsOneWidget);
        expect(find.textContaining('situação'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('[16] botão volume_up presente nas bolhas do tutor', (
      tester,
    ) async {
      await tester.pumpWidget(tutorApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up_outlined), findsAtLeastNWidgets(1));
    });
  });

  // ──────────────────────────────────────────
  // ETAPA 5 — Chat Experience
  // ──────────────────────────────────────────
  group('Chat Cartilha', () {
    setUp(_registerTestUser);

    testWidgets(
      '[17] abre cartilha e exibe primeira mensagem do tutor vizinho',
      (tester) async {
        await tester.pumpWidget(const CartilhasApp());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await tester.tap(find.byType(Card).first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(find.textContaining('vizinho'), findsAtLeastNWidgets(1));
      },
    );
  });
}
