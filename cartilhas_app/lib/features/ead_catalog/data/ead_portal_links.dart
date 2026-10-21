import 'package:url_launcher/url_launcher.dart';

import 'ead_catalog_repository.dart';

typedef EadPortalOpener = Future<bool> Function(Uri uri);

/// The EAD WordPress account owns enrollment and course registration.
/// Attribution is campaign-only: never append CPF, e-mail, phone or session IDs.
class EadPortalLinks {
  static const host = EadCatalogRepository.host;

  static const _source = 'tutor_tds_app';
  static const _medium = 'app';

  static Uri registration({int? courseId}) {
    if (courseId != null && courseId <= 0) {
      throw ArgumentError.value(courseId, 'courseId');
    }
    return Uri.https(host, '/cadastro/', {
      if (courseId != null) 'tds_curso': '$courseId',
      ..._attribution(
        campaign: 'ead_signup',
        content: courseId == null ? 'welcome_signup' : 'course_$courseId',
      ),
    });
  }

  static Uri login() => Uri.https(host, '/wp-login.php', {
    'redirect_to': Uri.https(host, '/minha-area/').toString(),
    ..._attribution(campaign: 'ead_login', content: 'welcome_login'),
  });

  static Uri course(EadCourse course) => course.url.replace(
    queryParameters: _attribution(
      campaign: 'ead_catalog',
      content: 'course_${course.id}',
    ),
  );

  static Map<String, String> _attribution({
    required String campaign,
    required String content,
  }) => {
    'utm_source': _source,
    'utm_medium': _medium,
    'utm_campaign': campaign,
    'utm_content': content,
  };

  /// Only HTTPS on the institutional host can receive a browser handoff.
  static bool isTrustedDestination(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host != host ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment) {
      return false;
    }
    if (uri.path == '/cadastro/') {
      final courseId = uri.queryParameters['tds_curso'];
      return courseId == null || RegExp(r'^[1-9][0-9]*$').hasMatch(courseId);
    }
    if (uri.path == '/wp-login.php') {
      return uri.queryParameters['redirect_to'] ==
          Uri.https(host, '/minha-area/').toString();
    }
    return RegExp(r'^/courses/[a-z0-9]+(?:-[a-z0-9]+)*/$').hasMatch(uri.path);
  }

  /// On mobile, Chrome Custom Tabs shares the portal's browser session;
  /// fallback opens the system browser. Neither option copies a password
  /// or WordPress cookie into the Flutter/TDS API authentication store.
  static Future<bool> open(Uri destination) async {
    if (!isTrustedDestination(destination)) return false;
    try {
      if (await launchUrl(destination, mode: LaunchMode.inAppBrowserView)) {
        return true;
      }
    } on Object {
      // Browser view unavailable; use the OS browser instead.
    }
    try {
      return await launchUrl(destination, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
