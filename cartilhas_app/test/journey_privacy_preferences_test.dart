import 'package:cartilhas_app/services/privacy_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Legacy authorization cannot silently enable the expanded journey scope',
    () async {
      SharedPreferences.setMockInitialValues({
        PrivacyPreferences.consentKey: true,
        PrivacyPreferences.noticeSeenKey: true,
      });
      expect(
        await PrivacyPreferences.hasConsent(journeyEnabled: false),
        isTrue,
      );
      expect(
        await PrivacyPreferences.hasSeenNotice(journeyEnabled: false),
        isTrue,
      );
      expect(
        await PrivacyPreferences.hasConsent(journeyEnabled: true),
        isFalse,
      );
      expect(
        await PrivacyPreferences.hasSeenNotice(journeyEnabled: true),
        isFalse,
      );
      await PrivacyPreferences.saveDecision(
        consent: false,
        journeyEnabled: true,
      );
      expect(
        await PrivacyPreferences.hasConsent(journeyEnabled: true),
        isFalse,
      );
      expect(
        await PrivacyPreferences.hasSeenNotice(journeyEnabled: true),
        isTrue,
      );
      expect(
        await PrivacyPreferences.hasConsent(journeyEnabled: false),
        isFalse,
      );
      await PrivacyPreferences.saveDecision(
        consent: true,
        journeyEnabled: true,
      );
      expect(await PrivacyPreferences.hasConsent(journeyEnabled: true), isTrue);
    },
  );
}
