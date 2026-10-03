import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../auth/data/auth_repository.dart';
import 'operations_controller.dart';
import 'operations_repository.dart';
import 'operations_screen.dart';

/// Both compile-time UI opt-in and server opt-in are required; no default grant.
const operatorOperationsEnabled = bool.fromEnvironment(
  'OPERATOR_OPERATIONS_ENABLED',
);

class OperationsEntry extends StatefulWidget {
  const OperationsEntry({super.key, required this.auth, required this.apiUrl});
  final AuthRepository auth;
  final String apiUrl;
  @override
  State<OperationsEntry> createState() => _OperationsEntryState();
}

class _OperationsEntryState extends State<OperationsEntry> {
  OperationsController? _controller;
  OperationsRepository? _repository;
  Timer? _sessionWatch;
  String? _error;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final generation = widget.auth.sessionGeneration;
    final owner = await widget.auth.localUserId();
    if (!mounted) return;
    if (!operatorOperationsEnabled ||
        owner == null ||
        generation != widget.auth.sessionGeneration) {
      setState(
        () => _error = 'Entre novamente para acessar a operação autorizada.',
      );
      return;
    }
    final random = Random.secure();
    final repository = OperationsRepository(
      apiUrl: widget.apiUrl,
      auth: widget.auth,
      owner: owner,
      generation: generation,
    );
    _repository = repository;
    _controller = OperationsController(
      repository,
      sessionKey: repository.sessionKey,
      nextCommandId: () => List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
    );
    // AuthRepository does not expose a notifier. Also validate each request;
    // this watcher clears idle sensitive UI on logout/account change.
    _sessionWatch = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (widget.auth.sessionGeneration != generation) {
        _controller?.replaceSession('expired');
        _sessionWatch?.cancel();
        if (mounted) {
          setState(
            () => _error =
                'A sessão mudou. Reabra a operação após entrar novamente.',
          );
        }
      }
    });
    setState(() {});
  }

  @override
  void dispose() {
    _sessionWatch?.cancel();
    _controller?.dispose();
    _repository?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _error != null
      ? Scaffold(
          appBar: AppBar(title: const Text('Operação de participantes')),
          body: Center(child: Text(_error!)),
        )
      : _controller == null
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : OperationsScreen(controller: _controller!);
}
