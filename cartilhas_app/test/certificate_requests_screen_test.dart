import 'package:cartilhas_app/features/certificates/data/certificate_request_repository.dart';
import 'package:cartilhas_app/features/certificates/models/certificate_request.dart';
import 'package:cartilhas_app/features/certificates/presentation/certificate_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const ready = CertificateRequestEligibility(
  requiredSeconds: 3600,
  validatedSeconds: 3600,
  completed: true,
  eligible: true,
);
const notReady = CertificateRequestEligibility(
  requiredSeconds: 3600,
  validatedSeconds: 300,
  completed: false,
  eligible: false,
);
CertificateRequest record({
  String state = 'pending',
  CertificateRequestEligibility evidence = ready,
  int revision = 1,
  String? reason,
  String classId = 'class',
}) => CertificateRequest(
  id: 'request',
  enrollmentId: 'enrollment',
  courseId: 'course',
  courseVersionId: 'version',
  classId: classId,
  className: 'Turma $classId',
  programId: 'program',
  holderName: 'Aluno de teste',
  courseTitle: 'Meu curso',
  programName: 'Programa TDS',
  institutionName: 'Instituto',
  status: state,
  revision: revision,
  requestedAt: DateTime.utc(2026, 9, 21),
  eligibility: evidence,
  reviewReason: reason,
);

class RequestsFake implements CertificateRequestGateway {
  List<CertificateRequest> rows = [];
  bool reviewer = false;
  bool conflict = false;
  bool sessionChanged = false;
  int creates = 0;
  int reviews = 0;
  int resubmits = 0;
  int? sentRevision;
  String? sentReason;
  @override
  Future<List<CertificateRequestContext>> contexts(
    String courseId,
    String versionId,
  ) async => const [
    CertificateRequestContext(
      enrollmentId: 'enrollment',
      programName: 'Programa TDS',
      courseVersionId: 'version',
      courseTitle: 'Meu curso',
      classId: 'class',
      className: 'Minha turma',
      eligibility: notReady,
    ),
  ];
  @override
  Future<CertificateRequest> create(CertificateRequestContext context) async {
    creates++;
    final row = record(evidence: notReady);
    rows = [row];
    return row;
  }

  @override
  Future<List<CertificateRequest>> ownRequests() async => rows;
  @override
  Future<List<CertificateRequest>> reviewQueue() async {
    if (sessionChanged) {
      throw const CertificateRequestException(
        'Sessão alterada.',
        statusCode: 401,
      );
    }
    if (!reviewer) {
      throw const CertificateRequestException(
        'Sem permissão.',
        statusCode: 403,
      );
    }
    return rows;
  }

  @override
  Future<CertificateRequest> detail(String id) async => rows.single;
  @override
  Future<CertificateRequest> review(
    String id,
    String decision,
    int revision,
    String reason,
  ) async {
    reviews++;
    sentRevision = revision;
    sentReason = reason;
    if (conflict) {
      throw const CertificateRequestException(
        'Pedido atualizado por outra pessoa. Atualize antes de decidir.',
        statusCode: 409,
      );
    }
    final row = record(
      state: decision == 'approve' ? 'approved' : 'rejected',
      revision: revision + 1,
      reason: reason,
    );
    rows = [row];
    return row;
  }

  @override
  Future<CertificateRequest> resubmit(String id, int revision) async {
    resubmits++;
    final row = record(revision: revision + 1);
    rows = [row];
    return row;
  }
}

Future<void> showRequests(
  WidgetTester tester,
  RequestsFake gateway, {
  bool review = false,
  bool course = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CertificateRequestsScreen(
        gateway: gateway,
        reviewMode: review,
        courseId: course ? 'course' : null,
        courseVersionId: course ? 'version' : null,
        classId: course ? 'class' : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('session change during optional probe does not expose old rows', (
    tester,
  ) async {
    final gateway = RequestsFake()
      ..rows = [record()]
      ..sessionChanged = true;
    await showRequests(tester, gateway);
    expect(find.text('Sessão alterada.'), findsOneWidget);
    expect(find.text('Meu curso'), findsNothing);
    expect(find.text('Programa TDS'), findsNothing);
  });

  testWidgets(
    'existing request in another class is identified without duplicate request',
    (tester) async {
      final gateway = RequestsFake()..rows = [record(classId: 'another-class')];
      await showRequests(tester, gateway, course: true);
      expect(find.text('Turma another-class'), findsOneWidget);
      expect(find.textContaining('outro contexto'), findsOneWidget);
      expect(find.text('Solicitar análise'), findsNothing);
      await tester.ensureVisible(find.text('Identificação do pedido'));
      await tester.tap(find.text('Identificação do pedido'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Matrícula: enrollment'), findsOneWidget);
      expect(find.textContaining('Edição: version'), findsOneWidget);
    },
  );
  testWidgets(
    'learner confirms request and sees pending, never instant certificate',
    (tester) async {
      final gateway = RequestsFake();
      await showRequests(tester, gateway, course: true);
      expect(find.byTooltip('Revisar pedidos'), findsNothing);
      expect(find.textContaining('Há critérios pendentes'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Solicitar análise'), 150);
      await tester.tap(find.text('Solicitar análise'));
      await tester.pumpAndSettle();
      expect(gateway.creates, 0);
      expect(find.textContaining('Este pedido não emite'), findsOneWidget);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(gateway.creates, 1);
      expect(find.text('Aguardando análise da equipe'), findsOneWidget);
      expect(find.text('Solicitar análise'), findsNothing);
      expect(find.text('Emitir certificado'), findsNothing);
    },
  );

  testWidgets(
    'human review requires reason and sends CAS revision, approved is not issued',
    (tester) async {
      final gateway = RequestsFake()
        ..reviewer = true
        ..rows = [record(revision: 7)];
      await showRequests(tester, gateway, review: true);
      await tester.scrollUntilVisible(find.text('Aprovar análise'), 150);
      await tester.tap(find.text('Aprovar análise'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar decisão'));
      await tester.pump();
      expect(gateway.reviews, 0);
      expect(find.text('Escreva a justificativa.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'Evidências conferidas pela equipe.',
      );
      await tester.tap(find.text('Registrar decisão'));
      await tester.pumpAndSettle();
      expect(gateway.sentRevision, 7);
      expect(gateway.sentReason, 'Evidências conferidas pela equipe.');
      expect(find.text('Aprovado — emissão pendente'), findsOneWidget);
      expect(find.text('Compartilhar PDF'), findsNothing);
    },
  );

  testWidgets(
    'ineligible disables approval but permits guidance; conflict does not change state',
    (tester) async {
      final gateway = RequestsFake()
        ..reviewer = true
        ..conflict = true
        ..rows = [record(evidence: notReady)];
      await showRequests(tester, gateway, review: true);
      await tester.scrollUntilVisible(find.text('Aprovar análise'), 150);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Aprovar análise'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Pedir ajustes'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Conclua as atividades pendentes.',
      );
      await tester.tap(find.text('Registrar decisão'));
      await tester.pumpAndSettle();
      expect(gateway.reviews, 1);
      expect(gateway.rows.single.status, 'pending');
      await tester.scrollUntilVisible(
        find.byKey(const Key('certificate-request-error')),
        -150,
      );
      expect(find.textContaining('Atualize antes de decidir'), findsOneWidget);
    },
  );

  testWidgets(
    'rejected request needs confirmation to resubmit and preserves server revision',
    (tester) async {
      final gateway = RequestsFake()
        ..rows = [
          record(state: 'rejected', revision: 3, reason: 'Revise a atividade.'),
        ];
      await showRequests(tester, gateway);
      await tester.scrollUntilVisible(find.text('Solicitar nova análise'), 150);
      await tester.tap(find.text('Solicitar nova análise'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(gateway.resubmits, 1);
      expect(gateway.rows.single.revision, 4);
      expect(find.text('Aguardando análise da equipe'), findsOneWidget);
    },
  );

  testWidgets(
    'review layout remains usable at 200 percent text in narrow viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = RequestsFake()
        ..reviewer = true
        ..rows = [record()];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CertificateRequestsScreen(gateway: gateway, reviewMode: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Aprovar análise'), 180);
      await tester.pumpAndSettle();
      expect(find.text('Aprovar análise').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
