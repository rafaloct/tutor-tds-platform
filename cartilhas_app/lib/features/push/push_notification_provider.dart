import 'package:cartilhas_app/config/app_config.dart';

import 'firebase_push_notification_service.dart';
import 'push_notification_service.dart';

Future<PushNotificationService> createConfiguredPushNotificationService(
  PushNavigationHandler onNavigation,
) {
  return const PushNotificationServiceFactory(
    FirebasePushBootstrapImpl(),
  ).create(
    enabled: AppConfig.pushNotificationsEnabled,
    config: AppConfig.firebasePushConfig,
    onNavigation: onNavigation,
  );
}
