import 'package:cartilhas_app/config/app_config.dart';
import 'package:cartilhas_app/features/push/push_notification_lifecycle.dart';
import 'package:cartilhas_app/features/push/push_notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  const completeConfig = FirebasePushConfig(
    apiKey: 'non-secret-key',
    appId: '1:123:android:abc',
    messagingSenderId: '123',
    projectId: 'project-id',
  );

  test(
    'disabled push uses no-op service without bootstrapping Firebase',
    () async {
      final bootstrap = _FakeBootstrap();
      final service = await PushNotificationServiceFactory(
        bootstrap,
      ).create(enabled: false, config: completeConfig, onNavigation: (_) {});

      expect(service, isA<NoopPushNotificationService>());
      expect(bootstrap.calls, 0);
    },
  );

  test(
    'incomplete Firebase config fails closed without bootstrapping',
    () async {
      final bootstrap = _FakeBootstrap();
      final service = await PushNotificationServiceFactory(bootstrap).create(
        enabled: true,
        config: const FirebasePushConfig(
          apiKey: '',
          appId: '1:123:android:abc',
          messagingSenderId: '123',
          projectId: 'project-id',
        ),
        onNavigation: (_) {},
      );

      expect(service, isA<NoopPushNotificationService>());
      expect(bootstrap.calls, 0);
    },
  );

  test('payload parser allows only the versioned support destination', () {
    expect(
      parsePushNavigationAction(const {
        'version': '1',
        'destination': 'support',
      }),
      PushNavigationAction.support,
    );
    expect(parsePushNavigationAction(const {'destination': 'support'}), isNull);
    expect(
      parsePushNavigationAction(const {
        'version': '1',
        'destination': 'course',
      }),
      isNull,
    );
    expect(
      parsePushNavigationAction(const {
        'version': '1',
        'destination': 'support',
        'deep_link': '/settings',
      }),
      isNull,
    );
  });

  testWidgets(
    'startup starts service but never requests notification permission',
    (tester) async {
      final service = _RecordingPushService();
      await tester.pumpWidget(
        Provider<PushNotificationService>.value(
          value: service,
          child: const PushNotificationLifecycle(child: SizedBox()),
        ),
      );

      expect(service.starts, 1);
      expect(service.permissionRequests, 0);
    },
  );

  test('navigation action contract exposes no academic destination', () {
    expect(PushNavigationAction.values, [PushNavigationAction.support]);
  });
}

class _FakeBootstrap implements FirebasePushBootstrap {
  int calls = 0;

  @override
  Future<PushNotificationService> create(
    PushNavigationHandler onNavigation,
  ) async {
    calls += 1;
    return NoopPushNotificationService();
  }
}

class _RecordingPushService implements PushNotificationService {
  int starts = 0;
  int permissionRequests = 0;

  @override
  void dispose() {}

  @override
  Future<void> requestPermission() async {
    permissionRequests += 1;
  }

  @override
  Future<void> start() async {
    starts += 1;
  }
}
