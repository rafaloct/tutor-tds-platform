import 'package:url_launcher/url_launcher.dart';

import '../../analytics/app_telemetry_service.dart';

enum CoursePdfResult { requested, unavailable, invalidLink, busy }

/// Dispatches the existing public material; it cannot observe external reading.
class CoursePdfController {
  CoursePdfController({Future<bool> Function(Uri)? launch})
    : _launch = launch ?? _external;

  final Future<bool> Function(Uri) _launch;
  bool isOpening = false;

  static Future<bool> _external(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<CoursePdfResult> open({
    required String? url,
    required String courseId,
    AppTelemetryService? telemetry,
  }) async {
    if (isOpening) return CoursePdfResult.busy;
    final uri = Uri.tryParse(url?.trim() ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return CoursePdfResult.invalidLink;
    }
    isOpening = true;
    try {
      // Queue the user's intent before handing off to another application.
      // Consent, account/session and offline ownership use the existing service.
      if (telemetry?.journeyEnabled == true) {
        await _recordRequest(telemetry!, courseId).timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );
      }
      return await _launch(uri)
          ? CoursePdfResult.requested
          : CoursePdfResult.unavailable;
    } on Object {
      return CoursePdfResult.unavailable;
    } finally {
      isOpening = false;
    }
  }

  Future<void> _recordRequest(
    AppTelemetryService telemetry,
    String courseId,
  ) async {
    try {
      await telemetry.trackFeature(
        featureId: 'course_pdf_open_requested',
        courseId: courseId,
      );
    } on Object {
      // Analytics must never prevent access to the course material.
    }
  }
}
