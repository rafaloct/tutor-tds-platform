import 'package:cartilhas_app/features/ead_account/presentation/ead_my_area_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EadMyAreaModel model({
  EadLinkState link = EadLinkState.linked,
  EadSnapshotState state = EadSnapshotState.current,
  int? viewer = 3,
  int? owner = 3,
  String env = 'staging',
  String? snapshotEnv = 'staging',
  bool verifiedSource = true,
  List<EadAreaCourse> courses = const [
    EadAreaCourse(
      wpCourseId: 1298,
      title: 'Agricultura Sustentável',
      enrollment: EadEnrollmentState.enrolled,
      progressPercent: 40,
      nextLesson: 'Aula 02: Plantio sustentável',
      resumeAuthorized: true,
    ),
  ],
}) => EadMyAreaModel(
  linkState: link,
  snapshotState: state,
  viewerWpUserId: viewer,
  snapshotWpUserId: owner,
  environmentId: env,
  snapshotEnvironmentId: snapshotEnv,
  authenticatedSourceVerified: verifiedSource,
  courses: courses,
);

Future<void> mount(
  WidgetTester tester, {
  required EadMyAreaModel data,
  VoidCallback? onLink,
  VoidCallback? onRetry,
  ValueChanged<int>? onResume,
  VoidCallback? onOpenCertificates,
  ThemeMode themeMode = ThemeMode.light,
  double fontScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 840);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(fontScale)),
        child: child!,
      ),
      home: EadMyAreaPreview(
        model: data,
        onLinkEad: onLink,
        onRetry: onRetry,
        onResumeCourse: onResume,
        onTdsCertificates: onOpenCertificates,
      ),
    ),
  );
  await tester.pump();
}

Future<void> scrollToTap(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.35);
  await tester.pumpAndSettle();
}

void main() {
  group('Minha área: identity and source boundaries', () {
    testWidgets('disconnected never renders injected private learner course', (
      tester,
    ) async {
      await mount(tester, data: model(link: EadLinkState.disconnected));
      expect(find.text('Conta EAD ainda não vinculada'), findsOneWidget);
      expect(find.text('Agricultura Sustentável'), findsNothing);
      expect(find.text('Progresso no LearnPress: 40%'), findsNothing);
      expect(
        find.textContaining('O catálogo público não demonstra'),
        findsOneWidget,
      );
    });

    testWidgets('link CTA only invokes explicit callback', (tester) async {
      var tapped = 0;
      await mount(
        tester,
        data: model(link: EadLinkState.disconnected),
        onLink: () => tapped++,
      );
      expect(tapped, 0);
      await tester.tap(find.text('Vincular conta EAD'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('without broker callback no fake account linking occurs', (
      tester,
    ) async {
      await mount(tester, data: model(link: EadLinkState.disconnected));
      final action = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Vincular conta EAD'),
      );
      expect(action.onPressed, isNull);
    });

    testWidgets('linking has no private data or account action', (
      tester,
    ) async {
      await mount(tester, data: model(link: EadLinkState.linking));
      expect(find.text('Vinculação EAD em andamento'), findsOneWidget);
      expect(find.text('Agricultura Sustentável'), findsNothing);
      expect(find.text('Vincular conta EAD'), findsNothing);
    });

    testWidgets('re-authentication required hides courses', (tester) async {
      await mount(tester, data: model(link: EadLinkState.loginRequired));
      expect(find.text('Sessão EAD precisa de novo acesso'), findsOneWidget);
      expect(find.text('Agricultura Sustentável'), findsNothing);
    });

    testWidgets('learner B cannot see A private state', (tester) async {
      await mount(tester, data: model(viewer: 4, owner: 3));
      expect(find.text('Confirme sua conta EAD novamente'), findsOneWidget);
      expect(find.text('Agricultura Sustentável'), findsNothing);
      expect(find.text('Progresso no LearnPress: 40%'), findsNothing);
    });

    testWidgets('separate staging and production scopes', (tester) async {
      await mount(
        tester,
        data: model(env: 'production', snapshotEnv: 'staging'),
      );
      expect(find.text('Agricultura Sustentável'), findsNothing);
    });

    testWidgets('unverified source never displays private course data', (
      tester,
    ) async {
      await mount(tester, data: model(verifiedSource: false));
      expect(find.text('Agricultura Sustentável'), findsNothing);
      expect(find.text('Progresso no LearnPress: 40%'), findsNothing);
    });

    testWidgets('no verified account ID shows no personal state', (
      tester,
    ) async {
      await mount(tester, data: model(viewer: null, owner: null));
      expect(find.text('Agricultura Sustentável'), findsNothing);
    });
  });

  group('Minha área: EAD courses and progress', () {
    testWidgets(
      'linked account renders official EAD source and known progress',
      (tester) async {
        await mount(tester, data: model());
        expect(find.text('Conta EAD vinculada'), findsOneWidget);
        expect(find.text('Agricultura Sustentável'), findsOneWidget);
        expect(find.text('Progresso no LearnPress: 40%'), findsOneWidget);
        expect(find.text('Inscrição no EAD confirmada'), findsOneWidget);
        expect(
          find.text('Próxima aula: Aula 02: Plantio sustentável'),
          findsOneWidget,
        );
      },
    );

    testWidgets('zero percent is an explicit known value, not absence', (
      tester,
    ) async {
      await mount(
        tester,
        data: model(
          courses: const [
            EadAreaCourse(
              wpCourseId: 1298,
              title: 'Agricultura Sustentável',
              enrollment: EadEnrollmentState.enrolled,
              progressPercent: 0,
            ),
          ],
        ),
      );
      expect(find.text('Progresso no LearnPress: 0%'), findsOneWidget);
      expect(find.text('Progresso EAD ainda não disponível.'), findsNothing);
    });

    testWidgets('null progress remains unknown and never appears as zero', (
      tester,
    ) async {
      await mount(
        tester,
        data: model(
          courses: const [
            EadAreaCourse(
              wpCourseId: 1298,
              title: 'Agricultura Sustentável',
              enrollment: EadEnrollmentState.enrolled,
            ),
          ],
        ),
      );
      expect(find.text('Progresso EAD ainda não disponível.'), findsOneWidget);
      expect(find.text('Progresso no LearnPress: 0%'), findsNothing);
    });

    testWidgets('invalid progress does not show misleading indicator', (
      tester,
    ) async {
      await mount(
        tester,
        data: model(
          courses: const [
            EadAreaCourse(
              wpCourseId: 1298,
              title: 'Agricultura Sustentável',
              enrollment: EadEnrollmentState.enrolled,
              progressPercent: 200,
            ),
          ],
        ),
      );
      expect(find.text('Progresso EAD ainda não disponível.'), findsOneWidget);
    });

    testWidgets('resume course requires explicit authorized current callback', (
      tester,
    ) async {
      int? courseId;
      await mount(tester, data: model(), onResume: (value) => courseId = value);
      final button = find.byKey(const ValueKey('ead-resume-1298'));
      await scrollToTap(tester, button);
      await tester.tap(button);
      expect(courseId, 1298);
    });

    testWidgets('cannot resume when no authorized callback exists', (
      tester,
    ) async {
      await mount(tester, data: model());
      final button = find.byKey(const ValueKey('ead-resume-1298'));
      await tester.ensureVisible(button);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });

    testWidgets('offline course list is visibly stale and read only', (
      tester,
    ) async {
      int? course;
      await mount(
        tester,
        data: model(state: EadSnapshotState.offline),
        onResume: (value) => course = value,
      );
      expect(find.textContaining('Sem conexão.'), findsOneWidget);
      final button = find.byKey(const ValueKey('ead-resume-1298'));
      await tester.ensureVisible(button);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(course, isNull);
    });

    testWidgets('stale state blocks resume until refreshed', (tester) async {
      await mount(
        tester,
        data: model(state: EadSnapshotState.stale),
        onResume: (_) {},
      );
      expect(find.textContaining('Consulta anterior'), findsOneWidget);
      final button = find.byKey(const ValueKey('ead-resume-1298'));
      await tester.ensureVisible(button);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });

    testWidgets('loading does not claim zero registrations', (tester) async {
      await mount(tester, data: model(state: EadSnapshotState.loading));
      expect(find.text('Consultando inscrições no EAD...'), findsOneWidget);
      expect(find.text('Agricultura Sustentável'), findsNothing);
      expect(find.textContaining('Nenhuma inscrição'), findsNothing);
    });

    testWidgets('error displays retry without private cached data', (
      tester,
    ) async {
      var retries = 0;
      await mount(
        tester,
        data: model(state: EadSnapshotState.error),
        onRetry: () => retries++,
      );
      expect(find.text('Agricultura Sustentável'), findsNothing);
      expect(find.textContaining('Não foi possível consultar'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ead-retry')));
      expect(retries, 1);
    });

    testWidgets('current empty enrollment gives explicit empty state', (
      tester,
    ) async {
      await mount(tester, data: model(courses: const []));
      expect(
        find.textContaining('Nenhuma inscrição EAD confirmada'),
        findsOneWidget,
      );
    });

    testWidgets('course finished in EAD is not official TDS certificate', (
      tester,
    ) async {
      await mount(
        tester,
        data: model(
          courses: const [
            EadAreaCourse(
              wpCourseId: 1298,
              title: 'Agricultura Sustentável',
              enrollment: EadEnrollmentState.completed,
              progressPercent: 100,
            ),
          ],
        ),
      );
      expect(find.text('Curso concluído no EAD'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Meus certificados oficiais'),
        290,
      );
      expect(
        find.textContaining('não emite certificado oficial'),
        findsOneWidget,
      );
    });
  });

  group('Minha área: institutional and layout separation', () {
    testWidgets('official TDS certificate button independent from EAD login', (
      tester,
    ) async {
      var taps = 0;
      await mount(
        tester,
        data: model(link: EadLinkState.disconnected),
        onOpenCertificates: () => taps++,
      );
      final button = find.text('Consultar certificados TDS');
      await tester.scrollUntilVisible(button, 290);
      await scrollToTap(tester, button);
      await tester.tap(button);
      expect(taps, 1);
    });

    testWidgets('large text and dark theme allow scroll without overflow', (
      tester,
    ) async {
      await mount(
        tester,
        data: model(),
        themeMode: ThemeMode.dark,
        fontScale: 1.8,
      );
      await tester.scrollUntilVisible(find.text('Precisa de ajuda?'), 340);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Precisa de ajuda?'), findsOneWidget);
    });

    testWidgets('switching from A to B hides old courses immediately', (
      tester,
    ) async {
      await mount(tester, data: model());
      expect(find.text('Agricultura Sustentável'), findsOneWidget);
      await mount(tester, data: model(viewer: 4, owner: 3));
      expect(find.text('Agricultura Sustentável'), findsNothing);
    });
  });
}
