import 'package:flutter/foundation.dart';

/// Optional product measurement. This boundary accepts categorical targets only;
/// academic identity, course IDs, answers and arbitrary event payloads stay out.
abstract interface class GoogleAnalyticsGateway {
  Future<void> setConsent(bool enabled);
  Future<void> reset();
  Future<void> log(String event, String target);
}

class GoogleUsageAnalytics extends ChangeNotifier {
  GoogleUsageAnalytics({
    required this.gateway,
    required this.readConsent,
    required this.writeConsent,
  });

  final GoogleAnalyticsGateway gateway;
  final Future<bool> Function() readConsent;
  final Future<void> Function(bool) writeConsent;
  Future<void> _tail = Future<void>.value();
  bool _allowed = false;
  bool? _applied;
  int _revision = 0;

  bool get consentGranted => _allowed;

  static const targets = {
    'page_viewed': {
      'welcome', 'home', 'onboarding', 'privacy_consent', 'privacy_policy',
      'account_login', 'profile', 'settings', 'content_catalog', 'study_hub',
      'guided_lesson', 'classroom_course', 'assessment', 'summary', 'flashcards',
      'glossary', 'tutor', 'ai_assistant', 'support', 'user_guide', 'videos',
      'video_player', 'certificate_wallet', 'certificate_details',
      'classroom_dashboard', 'team_dashboard',
    },
    'resource_opened': {
      'ai_chat', 'ai_exam', 'ai_flashcards', 'ai_quiz', 'ai_summary',
      'content_catalog', 'course_content', 'knowledge_glossary',
      'privacy_policy', 'study_tools', 'usage_guide', 'video_catalog',
      'video_content',
    },
    'feature_used': {
      'ai_tutor', 'assessment', 'content_navigation', 'flashcards',
      'glossary', 'glossary_explanation', 'guided_learning',
      'onboarding', 'onboarding_replay', 'quiz', 'study_hub',
      'study_hub_navigation', 'summary', 'support', 'tutor_help',
      'tutor_help_requested', 'video_learning', 'course_pdf_open_requested',
    },
  };

  Future<void> initialize() {
    final revision = _revision;
    return _serialize(() async {
      final stored = await readConsent();
      if (revision != _revision) return;
      await _apply(stored);
      _allowed = stored && revision == _revision;
      notifyListeners();
    });
  }

  Future<void> setConsent(bool enabled) {
    final revision = ++_revision;
    // Revocation takes effect synchronously, including already queued events.
    _allowed = false;
    notifyListeners();
    return _serialize(() async {
      await writeConsent(enabled);
      await _apply(enabled);
      _allowed = enabled && revision == _revision;
      notifyListeners();
    });
  }

  Future<void> track(String event, String target) {
    if (!_allowed || targets[event]?.contains(target) != true) {
      return Future<void>.value();
    }
    final revision = _revision;
    return _serialize(() async {
      if (!_allowed || revision != _revision) return;
      await gateway.log(event, target);
    });
  }

  Future<void> _apply(bool enabled) async {
    if (_applied == enabled) return;
    await gateway.setConsent(enabled);
    if (!enabled) await gateway.reset();
    _applied = enabled;
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    // Keep later revocation usable even after a transient SDK failure.
    _tail = result.catchError((Object _) {});
    return result;
  }
}
