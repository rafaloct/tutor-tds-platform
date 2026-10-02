import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class PrivacyPreferences {
  const PrivacyPreferences._();

  static const consentKey = 'privacy_consent_v1';
  static const noticeSeenKey = 'privacy_notice_seen_v1';
  static const journeyConsentKey = 'privacy_journey_consent_v1';
  static const journeyNoticeSeenKey = 'privacy_journey_notice_seen_v1';

  static Future<bool> hasConsent({
    bool journeyEnabled = AppConfig.journeyTraceabilityEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(journeyEnabled ? journeyConsentKey : consentKey) ??
        false;
  }

  static Future<bool> hasSeenNotice({
    bool journeyEnabled = AppConfig.journeyTraceabilityEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(
          journeyEnabled ? journeyNoticeSeenKey : noticeSeenKey,
        ) ??
        false;
  }

  static Future<void> saveDecision({
    required bool consent,
    bool journeyEnabled = AppConfig.journeyTraceabilityEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(consentKey, consent);
    await prefs.setBool(noticeSeenKey, true);
    if (journeyEnabled) {
      await prefs.setBool(journeyConsentKey, consent);
      await prefs.setBool(journeyNoticeSeenKey, true);
    }
  }
}
