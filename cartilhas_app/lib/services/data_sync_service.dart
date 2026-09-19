import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'privacy_preferences.dart';

class DataSyncService {
  static const String _adminEmail = 'tdsdados@gmail.com';

  static Future<bool> logEvent(String eventType, String detail) async {
    if (!await PrivacyPreferences.hasConsent()) {
      debugPrint(
        '[DataSync] Evento ignorado: compartilhamento não autorizado.',
      );
      return false;
    }

    final webhookUrl = AppConfig.analyticsWebhookUrl;
    if (webhookUrl.isEmpty) {
      debugPrint('[DataSync] Evento ignorado: endpoint não configurado.');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'N/A';
    final phone = prefs.getString('user_phone') ?? 'N/A';
    final cpf = prefs.getString('user_cpf') ?? 'N/A';

    try {
      final response = await http
          .post(
            Uri.parse(webhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'phone': phone,
              'cpf': cpf,
              'eventType': eventType,
              'detail': detail,
              'adminEmail': _adminEmail,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode >= 200 && response.statusCode < 300;
    } on Exception catch (e) {
      debugPrint('[DataSync] Erro ao enviar evento: $e');
      return false;
    }
  }
}
