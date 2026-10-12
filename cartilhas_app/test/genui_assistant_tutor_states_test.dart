import 'dart:async';

import 'package:cartilhas_app/features/analytics/app_telemetry_service.dart';
import 'package:cartilhas_app/models/tutor_learning_context.dart';
import 'package:cartilhas_app/screens/genui_assistant_screen.dart';
import 'package:cartilhas_app/services/anything_llm_service.dart';
import 'package:cartilhas_app/widgets/tutor_message_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeTutorService extends AnythingLLMService {
  _FakeTutorService() : super(gatewayUrl: 'https://fake.invalid');

  final List<TutorChatResult> queue = [];
  final List<String> calls = [];
  Completer<TutorChatResult>? pending;

  @override
  Future<TutorChatResult> getChatResponse(
    String message, {
    String mode = 'tutor',
    String? context,
    TutorLearningContext? learningContext,
  }) {
    calls.add(message);
    final held = pending;
    if (held != null) return held.future;
    if (queue.isNotEmpty) return Future.value(queue.removeAt(0));
    return Future.value(
      const TutorChatResult(
        TutorChatStatus.unavailable,
        TutorChatResult.unavailableText,
      ),
    );
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeTutorService service, {
  Future<void> Function(String)? speaker,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AnythingLLMService>.value(value: service),
        Provider<AppTelemetryService?>.value(value: null),
      ],
      child: MaterialApp(home: GenUIAssistantScreen(speaker: speaker)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ask(WidgetTester tester, String question) async {
  await tester.enterText(find.byType(TextField), question);
  await tester.tap(find.byTooltip('Enviar pergunta'));
}

void main() {
  testWidgets('resposta válida vira card educacional, não erro', (
    tester,
  ) async {
    final service = _FakeTutorService()
      ..queue.add(
        const TutorChatResult(
          TutorChatStatus.answer,
          '**Manejo da água** é essencial.',
        ),
      );
    await _pumpScreen(tester, service);

    await _ask(tester, 'O que é manejo da água?');
    await tester.pumpAndSettle();

    expect(find.text('Resposta direta'), findsOneWidget);
    expect(find.text('Criar cartões'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('502 indisponível vira liveRegion com retry irmão', (
    tester,
  ) async {
    final service = _FakeTutorService()
      ..queue.add(
        const TutorChatResult(
          TutorChatStatus.unavailable,
          TutorChatResult.unavailableText,
        ),
      );
    await _pumpScreen(tester, service);

    await _ask(tester, 'Pergunta que falha');
    await tester.pumpAndSettle();

    // Erro não aparece como resposta educacional normal.
    expect(find.text('Criar cartões'), findsNothing);
    expect(find.text('Praticar quiz'), findsNothing);
    expect(
      find.textContaining('temporariamente indisponível'),
      findsOneWidget,
    );

    // Nó liveRegion anuncia o erro; o botão de retry é irmão do nó
    // anunciado, nunca descendente dele nem com liveRegion como ancestral.
    final semanticsHandle = tester.ensureSemantics();
    final errorNode = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Erro do Tutor')),
    );
    expect(errorNode.flagsCollection.isLiveRegion, isTrue);
    expect(errorNode.label, contains('temporariamente indisponível'));
    expect(errorNode.label, isNot(contains('Tentar novamente')));
    semanticsHandle.dispose();

    final errorSemanticsWidget = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          (w.properties.liveRegion ?? false) &&
          (w.properties.label ?? '').startsWith('Erro do Tutor'),
    );
    expect(errorSemanticsWidget, findsOneWidget);
    expect(
      find.descendant(
        of: errorSemanticsWidget,
        matching: find.text('Tentar novamente'),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('Tentar novamente'),
        matching: errorSemanticsWidget,
      ),
      findsNothing,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('retry manual reenvia a mesma pergunta uma vez', (tester) async {
    final service = _FakeTutorService()
      ..queue.addAll([
        const TutorChatResult(
          TutorChatStatus.unavailable,
          TutorChatResult.unavailableText,
        ),
        const TutorChatResult(TutorChatStatus.answer, 'Funcionou.'),
      ]);
    await _pumpScreen(tester, service);

    await _ask(tester, 'Pergunta instável');
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(service.calls, ['Pergunta instável', 'Pergunta instável']);
    expect(find.text('Resposta direta'), findsOneWidget);
    // retry oculto: pergunta não duplica na lista
    expect(find.text('Pergunta instável'), findsOneWidget);
  });

  testWidgets('resposta vazia também não vira card de ações', (tester) async {
    final service = _FakeTutorService()
      ..queue.add(
        const TutorChatResult(
          TutorChatStatus.emptyAnswer,
          TutorChatResult.emptyAnswerText,
        ),
      );
    await _pumpScreen(tester, service);

    await _ask(tester, 'Pergunta sem resposta');
    await tester.pumpAndSettle();

    expect(find.text('Criar cartões'), findsNothing);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(
      find.textContaining('reformular a pergunta'),
      findsOneWidget,
    );
  });

  testWidgets('Ouvir envia ao TTS texto sem sintaxe Markdown', (tester) async {
    final spoken = <String>[];
    final service = _FakeTutorService()
      ..queue.add(
        const TutorChatResult(
          TutorChatStatus.answer,
          '**Essencial:** veja [a cartilha](https://exemplo.br/doc) e `solo`.',
        ),
      );
    await _pumpScreen(
      tester,
      service,
      speaker: (text) async => spoken.add(text),
    );

    await _ask(tester, 'Pergunta');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ouvir'));
    await tester.pumpAndSettle();

    expect(spoken, hasLength(1));
    expect(spoken.single, isNot(contains('**')));
    expect(spoken.single, isNot(contains('](')));
    expect(spoken.single, isNot(contains('`')));
    expect(spoken.single, contains('a cartilha'));
    expect(spoken.single, contains('Essencial'));
  });

  testWidgets('link seguro abre diálogo de confirmação', (tester) async {
    final service = _FakeTutorService()
      ..queue.add(
        const TutorChatResult(
          TutorChatStatus.answer,
          'Veja [a cartilha](https://exemplo.br/doc) oficial.',
        ),
      );
    await _pumpScreen(tester, service);

    await _ask(tester, 'Onde está a cartilha?');
    await tester.pumpAndSettle();

    await tester.tapOnText(
      find.textRange.ofSubstring(
        'a cartilha',
        descendentOf: find.byType(TutorMessageText),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirmar redirecionamento'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar redirecionamento'), findsNothing);
  });

  testWidgets('loading aparece enquanto a resposta está pendente', (
    tester,
  ) async {
    final service = _FakeTutorService()
      ..pending = Completer<TutorChatResult>();
    await _pumpScreen(tester, service);

    await _ask(tester, 'Pergunta lenta');
    await tester.pump();

    expect(find.text('Tutor preparando a resposta'), findsOneWidget);

    service.pending!.complete(
      const TutorChatResult(TutorChatStatus.answer, 'Chegou.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resposta direta'), findsOneWidget);
  });
}
