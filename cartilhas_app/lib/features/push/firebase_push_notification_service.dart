import 'dart:async';

import 'package:cartilhas_app/config/app_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_notification_service.dart';

class FirebasePushBootstrapImpl implements FirebasePushBootstrap {
  const FirebasePushBootstrapImpl();

  @override
  Future<PushNotificationService> create(
    PushNavigationHandler onNavigation,
  ) async => FirebasePushNotificationService(
    AppConfig.firebasePushConfig,
    onNavigation,
  );
}

class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService(this._configuration, this._onNavigation);

  final FirebasePushConfig _configuration;
  final PushNavigationHandler _onNavigation;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _started = false;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _configuration.apiKey,
          appId: _configuration.appId,
          messagingSenderId: _configuration.messagingSenderId,
          projectId: _configuration.projectId,
        ),
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleMessage,
      );
      _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleMessage,
      );
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((_) {});
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) _handleMessage(initialMessage);
    } on Exception {
      // Firebase remains inactive; startup and all academic flows continue.
    }
  }

  void _handleMessage(RemoteMessage message) {
    final action = parsePushNavigationAction(
      message.data.map<String, Object?>((key, value) => MapEntry(key, value)),
    );
    if (action != null) _onNavigation(action);
  }

  @override
  Future<void> requestPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } on Exception {
      // An explicit request may fail without changing app state.
    }
  }

  @override
  void dispose() {
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedAppSubscription?.cancel());
    unawaited(_tokenRefreshSubscription?.cancel());
  }
}
