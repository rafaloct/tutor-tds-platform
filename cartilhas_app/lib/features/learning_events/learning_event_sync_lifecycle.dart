import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import 'learning_event_sync_service.dart';

class LearningEventSyncLifecycle extends StatefulWidget {
  const LearningEventSyncLifecycle({super.key, required this.child});

  final Widget child;

  @override
  State<LearningEventSyncLifecycle> createState() =>
      _LearningEventSyncLifecycleState();
}

class _LearningEventSyncLifecycleState extends State<LearningEventSyncLifecycle>
    with WidgetsBindingObserver {
  Timer? _retry;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _flush();
        _startRetry();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _retry?.cancel();
    if (state == AppLifecycleState.resumed) {
      _flush();
      _startRetry();
    }
  }

  void _startRetry() {
    if (!AppConfig.durableLearningOutboxEnabled) return;
    _retry?.cancel();
    _retry = Timer.periodic(const Duration(seconds: 30), (_) => _flush());
  }

  void _flush() {
    unawaited(
      context.read<LearningEventSyncService>().flush().catchError((
        Object error,
        StackTrace stack,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'learning outbox',
          ),
        );
        return 0;
      }),
    );
  }

  @override
  void dispose() {
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
