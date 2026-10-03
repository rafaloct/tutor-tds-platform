import 'package:cartilhas_app/config/app_config.dart';

/// The only destination accepted from a push payload in this foundation.
/// It is deliberately non-academic and has no auth authority.
enum PushNavigationAction { support }

typedef PushNavigationHandler = void Function(PushNavigationAction action);

PushNavigationAction? parsePushNavigationAction(Map<String, Object?> payload) {
  if (payload.length != 2 ||
      payload['version'] != '1' ||
      payload['destination'] != PushNavigationAction.support.name) {
    return null;
  }
  return PushNavigationAction.support;
}

abstract interface class PushNotificationService {
  /// Starts listeners only. It must never request notification permission.
  Future<void> start();

  /// Reserved for an explicit, user-initiated settings action.
  Future<void> requestPermission();

  void dispose();
}

class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  void dispose() {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> start() async {}
}

abstract interface class FirebasePushBootstrap {
  Future<PushNotificationService> create(PushNavigationHandler onNavigation);
}

class PushNotificationServiceFactory {
  const PushNotificationServiceFactory(this._bootstrap);

  final FirebasePushBootstrap _bootstrap;

  Future<PushNotificationService> create({
    required bool enabled,
    required FirebasePushConfig config,
    required PushNavigationHandler onNavigation,
  }) async {
    if (!enabled || !config.isComplete) {
      return const NoopPushNotificationService();
    }
    return _bootstrap.create(onNavigation);
  }
}
