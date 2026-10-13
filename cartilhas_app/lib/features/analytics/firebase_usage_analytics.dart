import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import 'google_usage_analytics.dart';

/// Android is the release target. Other platforms remain disabled until their
/// own Firebase registration and native consent defaults have been validated.
GoogleUsageAnalytics? createGoogleUsageAnalytics() {
  if (!AppConfig.googleAnalyticsEnabled ||
      !const {'staging', 'production'}.contains(AppConfig.environment) ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android ||
      !AppConfig.firebasePushConfig.isComplete ||
      !AppConfig.firebasePushConfig.appId.contains(':android:')) {
    return null;
  }
  const config = AppConfig.firebasePushConfig;
  final key = 'privacy_google_analytics_v1:'
      '${AppConfig.environment}:${config.projectId}:${config.appId}';
  return GoogleUsageAnalytics(
    gateway: FirebaseUsageAnalyticsGateway(config),
    readConsent: () async =>
        (await SharedPreferences.getInstance()).getBool(key) ?? false,
    writeConsent: (value) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(key, value)) {
        throw StateError('Não foi possível salvar a preferência de uso.');
      }
    },
  );
}

class FirebaseUsageAnalyticsGateway implements GoogleAnalyticsGateway {
  FirebaseUsageAnalyticsGateway(this.config);

  final FirebasePushConfig config;
  FirebaseAnalytics? _analytics;

  Future<FirebaseAnalytics> _instance() async {
    if (_analytics != null) return _analytics!;
    final app = await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config.apiKey,
        appId: config.appId,
        messagingSenderId: config.messagingSenderId,
        projectId: config.projectId,
      ),
    );
    if (app.options.appId != config.appId ||
        app.options.projectId != config.projectId) {
      throw StateError('Projeto Firebase divergente.');
    }
    return _analytics = FirebaseAnalytics.instanceFor(app: app);
  }

  @override
  Future<void> setConsent(bool enabled) async {
    final analytics = await _instance();
    // Disable first; no advertising consent or academic user ID is granted.
    await analytics.setAnalyticsCollectionEnabled(false);
    await analytics.setConsent(
      analyticsStorageConsentGranted: enabled,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
    await analytics.setUserId(id: null);
    if (enabled) await analytics.setAnalyticsCollectionEnabled(true);
  }

  @override
  Future<void> reset() async => (await _instance()).resetAnalyticsData();

  @override
  Future<void> log(String event, String target) async {
    final analytics = await _instance();
    if (event == 'page_viewed') {
      await analytics.logScreenView(screenName: target, screenClass: 'TutorTDS');
    } else {
      await analytics.logEvent(name: event, parameters: {'target': target});
    }
  }
}
