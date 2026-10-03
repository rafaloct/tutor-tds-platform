import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'push_notification_service.dart';

class PushNotificationLifecycle extends StatefulWidget {
  const PushNotificationLifecycle({super.key, required this.child});

  final Widget child;

  @override
  State<PushNotificationLifecycle> createState() =>
      _PushNotificationLifecycleState();
}

class _PushNotificationLifecycleState extends State<PushNotificationLifecycle> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<PushNotificationService>().start());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
