import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'chatwoot_config.dart';

abstract interface class ChatwootConfigRepository {
  Future<ChatwootConfig> fetch();
}

class ChatwootConfigUnavailable implements Exception {
  const ChatwootConfigUnavailable();
}

/// Fetches every opening/retry. No successful or failed response is cached.
class HttpChatwootConfigRepository implements ChatwootConfigRepository {
  HttpChatwootConfigRepository({
    String? apiUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : apiUrl = apiUrl ?? AppConfig.tutorApiUrl,
       _client = client ?? http.Client();

  final String apiUrl;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<ChatwootConfig> fetch() async {
    try {
      final base = Uri.tryParse(apiUrl);
      if (base == null ||
          base.scheme != 'https' ||
          base.host.isEmpty ||
          base.userInfo.isNotEmpty ||
          apiUrl.split('://').last.split('/').first.contains('@') ||
          base.hasQuery ||
          base.hasFragment) {
        throw const ChatwootConfigUnavailable();
      }
      final endpoint = base
          .replace(path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/')
          .resolve('support/config');
      final response = await _client
          .get(
            endpoint,
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache, no-store',
            },
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw const ChatwootConfigUnavailable();
      }
      return ChatwootConfig.fromJson(jsonDecode(response.body));
    } on Object {
      // Keep URLs, inbox tokens and provider response bodies out of UI/logs.
      throw const ChatwootConfigUnavailable();
    }
  }

  void dispose() => _client.close();
}
