import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _flush();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _flush();
  }

  void _flush() {
    unawaited(context.read<LearningEventSyncService>().flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
