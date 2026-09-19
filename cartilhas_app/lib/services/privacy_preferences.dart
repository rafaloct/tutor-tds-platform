import 'package:shared_preferences/shared_preferences.dart';

class PrivacyPreferences {
  const PrivacyPreferences._();

  static const consentKey = 'privacy_consent_v1';
  static const noticeSeenKey = 'privacy_notice_seen_v1';

  static Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(consentKey) ?? false;
  }

  static Future<bool> hasSeenNotice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(noticeSeenKey) ?? false;
  }

  static Future<void> saveDecision({required bool consent}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(consentKey, consent);
    await prefs.setBool(noticeSeenKey, true);
  }
}
