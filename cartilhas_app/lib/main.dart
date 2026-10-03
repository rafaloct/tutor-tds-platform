import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/welcome_screen.dart';
import 'config/app_config.dart';
import 'services/anything_llm_service.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';
import 'features/study_ai/data/study_ai_service.dart';
import 'features/study_ai/data/assessment_sync_service.dart';
import 'features/certificates/data/certificate_service.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/external_identity_service.dart';
import 'features/learning_events/learning_event_sync_service.dart';
import 'features/learning_events/learning_event_sync_lifecycle.dart';
import 'features/analytics/app_telemetry_service.dart';
import 'features/analytics/telemetry_route.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.externalAuthConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabasePublishableKey,
    );
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  runApp(const CartilhasApp());
}

class CartilhasApp extends StatefulWidget {
  const CartilhasApp({super.key});

  @override
  State<CartilhasApp> createState() => _CartilhasAppState();
}

class _CartilhasAppState extends State<CartilhasApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController()..load();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeController),
        Provider(
          create: (_) =>
              AnythingLLMService(gatewayUrl: AppConfig.tutorGatewayUrl),
        ),
        Provider(
          create: (_) => StudyAiService(gatewayUrl: AppConfig.tutorGatewayUrl),
          dispose: (_, service) => service.dispose(),
        ),
        Provider(
          create: (_) =>
              CertificateService(gatewayUrl: AppConfig.tutorGatewayUrl),
          dispose: (_, service) => service.dispose(),
        ),
        Provider(
          create: (_) => AuthRepository(apiUrl: AppConfig.tutorApiUrl),
          dispose: (_, repository) => repository.dispose(),
        ),
        Provider(
          create: (context) => ExternalIdentityService(
            tutorAuth: context.read<AuthRepository>(),
          ),
        ),
        Provider<AssessmentSyncCoordinator>(
          create: (context) => AssessmentSyncService(
            apiUrl: AppConfig.tutorApiUrl,
            authRepository: context.read<AuthRepository>(),
          ),
          dispose: (_, coordinator) {
            if (coordinator is AssessmentSyncService) coordinator.dispose();
          },
        ),
        Provider(
          create: (context) => LearningEventSyncService(
            apiUrl: AppConfig.tutorApiUrl,
            authRepository: context.read<AuthRepository>(),
          ),
          dispose: (_, service) => service.dispose(),
        ),
        Provider(
          create: (context) => AppTelemetryService(
            syncService: context.read<LearningEventSyncService>(),
          ),
        ),
      ],
      child: LearningEventSyncLifecycle(child: const _AppView()),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> with WidgetsBindingObserver {
  TelemetryNavigatorObserver? _telemetryObserver;
  Timer? _screenHeartbeat;

  @override
  void initState() {
    super.initState();
    if (AppConfig.journeyTraceabilityEnabled) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _telemetryObserver ??= TelemetryNavigatorObserver(
      context.read<AppTelemetryService>(),
    );
    if (AppConfig.journeyTraceabilityEnabled) {
      _screenHeartbeat ??= Timer.periodic(const Duration(seconds: 15), (_) {
        context.read<AppTelemetryService>().heartbeatScreen().catchError(
          (Object _) {},
        );
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<AppTelemetryService>().setForeground(
      state == AppLifecycleState.resumed,
    );
  }

  @override
  void dispose() {
    _screenHeartbeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, themeController, _) => MaterialApp(
        title: 'Tutor TDS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeController.themeMode,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        navigatorObservers: [_telemetryObserver!],
        builder: (context, child) => ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Listener(
            onPointerDown: (_) => context.read<AppTelemetryService>().touch(),
            onPointerSignal: (_) => context.read<AppTelemetryService>().touch(),
            child: SafeArea(
              top: false,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
        home: const WelcomeScreen(),
      ),
    );
  }
}
