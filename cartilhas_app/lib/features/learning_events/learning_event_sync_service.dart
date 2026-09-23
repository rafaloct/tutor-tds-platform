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
    this.clock = DateTime.now,
  }) : _client = client ?? http.Client();

  final String apiUrl;
  final AuthRepository authRepository;
  final LearningEventQueue queue;
  final http.Client _client;
  final ConsentChecker consentChecker;
  final DateTime Function() clock;
  Future<int>? _flushInFlight;
  bool _flushAgain = false;

  Future<int> flush() {
    final current = _flushInFlight;
    if (current != null) {
      _flushAgain = true;
      return current;
    }
    final operation = _drain();
    _flushInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_flushInFlight, operation)) _flushInFlight = null;
    });
  }

  Future<int> _drain() async {
    var synced = 0;
    do {
      _flushAgain = false;
      synced += await _flush();
    } while (_flushAgain);
    return synced;
  }

  Future<int> _flush() async {
    var synced = 0;
    String? currentId;
    try {
      if (apiUrl.trim().isEmpty || !authRepository.isConfigured) return 0;
      if (!await consentChecker()) return 0;

      final events = await queue.ready(clock());
      for (final event in events) {
        // A legacy event without an owner cannot be assigned to whoever logs in
        // next. Keep it for explicit reconciliation, never infer its owner.
        if (queue.isDurable && event.localOwnerId == null) continue;
        if (event.localOwnerId != null &&
            (event.localApiUrl != apiUrl.replaceFirst(RegExp(r'/+$'), '') ||
                event.localOwnerId != await authRepository.localUserId())) {
          continue;
        }
        currentId = event.eventId;
        final response = await authRepository.authorized((accessToken) async {
          if (event.localOwnerId != null &&
              event.localOwnerId != await authRepository.localUserId()) {
            throw const AuthException('A conta mudou durante a sincronização.');
          }
          return _client
              .post(
                _uri('/events'),
                headers: {
                  'Authorization': 'Bearer $accessToken',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(event.toJson()),
              )
              .timeout(const Duration(seconds: 12));
        });
        if (response.statusCode != 200 && response.statusCode != 201) {
          await queue.recordFailure(
            event.eventId,
            now: clock(),
            statusCode: response.statusCode,
          );
          if (queue.isDurable &&
              response.statusCode != 401 &&
              response.statusCode != 403) {
            continue;
          }
          return synced;
        }
        if (await queue.removeById(event.eventId)) synced++;
      }
    } on TimeoutException {
      if (currentId != null) await queue.recordFailure(currentId, now: clock());
      return synced;
    } on http.ClientException {
      if (currentId != null) await queue.recordFailure(currentId, now: clock());
      return synced;
    } on AuthException {
      if (currentId != null) {
        await queue.recordFailure(currentId, now: clock(), statusCode: 401);
      }
      return synced;
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
