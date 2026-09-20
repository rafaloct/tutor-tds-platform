import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/privacy_preferences.dart';
import '../auth/data/auth_repository.dart';
import 'learning_event_queue.dart';

typedef ConsentChecker = Future<bool> Function();

class LearningEventSyncService {
  LearningEventSyncService({
    required this.apiUrl,
    required this.authRepository,
    this.queue = const LearningEventQueue(),
    http.Client? client,
    this.consentChecker = PrivacyPreferences.hasConsent,
  }) : _client = client ?? http.Client();

  final String apiUrl;
  final AuthRepository authRepository;
  final LearningEventQueue queue;
  final http.Client _client;
  final ConsentChecker consentChecker;
  Future<int>? _flushInFlight;

  Future<int> flush() {
    final current = _flushInFlight;
    if (current != null) return current;
    final operation = _flush();
    _flushInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_flushInFlight, operation)) _flushInFlight = null;
    });
  }

  Future<int> _flush() async {
    if (apiUrl.trim().isEmpty || !authRepository.isConfigured) return 0;
    if (!await consentChecker()) return 0;

    final events = await queue.pending();
    var synced = 0;
    for (final event in events) {
      try {
        final response = await authRepository.authorized(
          (accessToken) => _client
              .post(
                _uri('/events'),
                headers: {
                  'Authorization': 'Bearer $accessToken',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(event.toJson()),
              )
              .timeout(const Duration(seconds: 12)),
        );
        if (response.statusCode != 200 && response.statusCode != 201) {
          return synced;
        }
        if (await queue.removeById(event.eventId)) synced++;
      } on Object {
        // A fila é a fonte de verdade: qualquer falha preserva este evento e
        // os seguintes para uma tentativa posterior.
        return synced;
      }
    }
    return synced;
  }

  Uri _uri(String path) {
    final base = apiUrl.endsWith('/')
        ? apiUrl.substring(0, apiUrl.length - 1)
        : apiUrl;
    return Uri.parse('$base$path');
  }

  void dispose() => _client.close();
}
