import 'dart:async';

import 'package:cartilhas_app/features/certificates/data/certificate_service.dart';
import 'package:cartilhas_app/features/certificates/models/certificate_record.dart';
import 'package:cartilhas_app/features/certificates/presentation/certificate_details_screen.dart';
import 'package:cartilhas_app/features/certificates/presentation/certificate_wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('detalhe apresenta QR, integridade e validação online', (
    tester,
  ) async {
    final response = Completer<bool>();
    final certificate = _certificate();
    final service = _FakeCertificateService(verify: (_) => response.future);

    await _pump(
      tester,
      service,
      CertificateDetailsScreen(certificate: certificate),
    );
    expect(find.text('Validando no servidor'), findsOneWidget);
    expect(find.text('CERTIFICADO'), findsOneWidget);
    expect(find.text(certificate.holderName), findsOneWidget);
    expect(find.text(certificate.courseTitle), findsOneWidget);
    expect(find.text(certificate.id), findsOneWidget);
    expect(find.text('4/4 perguntas'), findsOneWidget);
    expect(find.text(certificate.hash), findsOneWidget);

    response.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Registro verificado'), findsOneWidget);
  });

  testWidgets('detalhe mantém estado offline e ações acessíveis', (
    tester,
  ) async {
    final service = _FakeCertificateService(
      verify: (_) async => false,
      actionError: StateError('compartilhamento indisponível'),
    );

    await _pump(
      tester,
      service,
      CertificateDetailsScreen(certificate: _certificate()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível validar agora'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pump();
    expect(find.text('Compartilhar PDF'), findsOneWidget);
    expect(find.text('Imprimir'), findsOneWidget);
    expect(find.text('Enviar por e-mail'), findsOneWidget);
    expect(find.text('Abrir validação'), findsOneWidget);
    await tester.tap(find.text('Compartilhar PDF'));
    await tester.pump();
    expect(find.textContaining('Não foi possível concluir:'), findsOneWidget);
  });

  testWidgets('carteira vazia explica como obter certificado', (tester) async {
    final service = _FakeCertificateService();
    await _pump(tester, service, const CertificateWalletScreen());
    await tester.pump();

    expect(find.text('Sua carteira está vazia'), findsOneWidget);
    expect(find.textContaining('Conclua uma cartilha'), findsOneWidget);
    expect(find.byTooltip('Selecionar todos'), findsNothing);
  });

  testWidgets('carteira lista, seleciona e abre detalhes reais', (
    tester,
  ) async {
    final first = _certificate();
    final second = _certificate(
      id: 'TDS-2026-123456ABCDEF',
      courseId: 'saf',
      courseTitle: 'Sistemas Agroflorestais',
    );
    final service = _FakeCertificateService(
      records: [first, second],
      verify: (_) async => true,
    );

    await _pump(tester, service, const CertificateWalletScreen());
    await tester.pump();
    expect(find.text(first.courseTitle), findsOneWidget);
    expect(find.text(second.courseTitle), findsOneWidget);
    expect(find.textContaining('Hash verificado'), findsNWidgets(2));

    await tester.longPress(find.text(first.courseTitle));
    await tester.pump();
    expect(find.text('1 selecionado'), findsOneWidget);
    expect(find.text('Imprimir'), findsOneWidget);
    expect(find.text('Exportar'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);

    await tester.tap(find.text('Exportar'));
    await tester.pump();
    expect(service.shareCalls, 1);

    await tester.tap(find.byTooltip('Selecionar todos'));
    await tester.pump();
    expect(find.text('2 selecionados'), findsOneWidget);
    expect(find.byTooltip('Limpar seleção'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar seleção'));
    await tester.pump();
    expect(find.text('Meus certificados'), findsOneWidget);

    await tester.tap(find.text(first.courseTitle));
    await tester.pumpAndSettle();
    expect(find.text('Certificado'), findsOneWidget);
    await tester.pump();
    expect(find.text('Registro verificado'), findsOneWidget);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Meus certificados'), findsOneWidget);
  });

  testWidgets('carteira mostra erro de leitura e permite tentar novamente', (
    tester,
  ) async {
    final service = _FakeCertificateService(
      loadError: StateError('armazenamento indisponível'),
    );

    await _pump(tester, service, const CertificateWalletScreen());
    await tester.pump();
    expect(
      find.text('Não foi possível abrir a carteira neste momento.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(
      find.text('Não foi possível abrir a carteira neste momento.'),
      findsOneWidget,
    );
  });

  testWidgets('detalhe mantém ações semânticas com fonte 200% estreita', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final certificate = _certificate();

    await _pumpScaled(
      tester,
      _FakeCertificateService(verify: (_) async => true),
      CertificateDetailsScreen(certificate: certificate),
    );
    await tester.pumpAndSettle();

    expect(find.text(certificate.holderName), findsOneWidget);
    expect(
      tester
          .getSemantics(find.widgetWithText(FilledButton, 'Compartilhar PDF'))
          .label,
      contains('Compartilhar PDF'),
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('carteira suporta fonte 200% em telefone landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final certificate = _certificate();

    await _pumpScaled(
      tester,
      _FakeCertificateService(records: [certificate]),
      const CertificateWalletScreen(),
    );
    await tester.pump();

    expect(find.text(certificate.courseTitle), findsOneWidget);
    expect(
      tester.getSemantics(find.byTooltip('Selecionar todos')).tooltip,
      'Selecionar todos',
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  CertificateService service,
  Widget child,
) {
  return tester.pumpWidget(
    Provider<CertificateService>.value(
      value: service,
      child: MaterialApp(theme: ThemeData(useMaterial3: true), home: child),
    ),
  );
}

Future<void> _pumpScaled(
  WidgetTester tester,
  CertificateService service,
  Widget child,
) {
  return tester.pumpWidget(
    Provider<CertificateService>.value(
      value: service,
      child: MaterialApp(
        builder: (context, appChild) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: appChild!,
        ),
        home: child,
      ),
    ),
  );
}

class _FakeCertificateService implements CertificateService {
  _FakeCertificateService({
    this.records = const [],
    this.verify,
    this.loadError,
    this.actionError,
  });

  final List<CertificateRecord> records;
  final Future<bool> Function(CertificateRecord certificate)? verify;
  final Object? loadError;
  final Object? actionError;
  int shareCalls = 0;
  int printCalls = 0;

  @override
  Future<List<CertificateRecord>> loadAll() async {
    if (loadError != null) throw loadError!;
    return records;
  }

  @override
  Future<bool> verifyOnline(CertificateRecord certificate) =>
      verify?.call(certificate) ?? Future<bool>.value(false);

  @override
  Future<void> shareCertificates(
    List<CertificateRecord> certificates, {
    bool email = false,
  }) async {
    shareCalls++;
    if (actionError != null) throw actionError!;
  }

  @override
  Future<void> printCertificates(List<CertificateRecord> certificates) async {
    printCalls++;
    if (actionError != null) throw actionError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CertificateRecord _certificate({
  String id = 'TDS-2026-ABCDEF123456',
  String courseId = 'cooperativismo',
  String courseTitle = 'Cooperativismo e Crédito',
}) {
  final unsigned = CertificateRecord(
    schemaVersion: 1,
    id: id,
    issuer: 'Tutor TDS - Programa TDS',
    holderName: 'Maria da Silva',
    courseId: courseId,
    courseTitle: courseTitle,
    issuedAt: DateTime.utc(2026, 8, 11, 12, 34, 56),
    answeredQuestions: 4,
    totalQuestions: 4,
    verificationUrl: Uri.parse('https://gateway.example/verify/$id'),
    hash: '',
    signature: 'c' * 64,
  );
  return CertificateRecord(
    schemaVersion: unsigned.schemaVersion,
    id: unsigned.id,
    issuer: unsigned.issuer,
    holderName: unsigned.holderName,
    courseId: unsigned.courseId,
    courseTitle: unsigned.courseTitle,
    issuedAt: unsigned.issuedAt,
    answeredQuestions: unsigned.answeredQuestions,
    totalQuestions: unsigned.totalQuestions,
    verificationUrl: unsigned.verificationUrl,
    hash: unsigned.computedHash,
    signature: unsigned.signature,
  );
}
