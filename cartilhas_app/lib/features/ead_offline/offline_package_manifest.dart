import 'dart:convert';

/// Public media only. This document is data, never an authorization grant.
class OfflinePackageManifest {
  OfflinePackageManifest._({
    required this.courseId,
    required this.lessonId,
    required this.contentRevision,
    required this.mobileContent,
    required this.rightsApproved,
    required this.mp4,
    required this.vtt,
    required this.title,
  });

  static const maxMp4Bytes = 500 * 1024 * 1024 - 1;
  static const maxPackageBytes = 700 * 1024 * 1024 - 1;
  static final _sha = RegExp(r'^[0-9a-f]{64}$');
  static final _safePath = RegExp(
    r'^/wp-content/uploads/tutor-tds/[A-Za-z0-9_/-]+\.(mp4|vtt)$',
  );

  final int courseId;
  final int lessonId;
  final String contentRevision;
  final bool mobileContent;
  final bool rightsApproved;
  final OfflineAsset mp4;
  final OfflineAsset? vtt;
  final String? title;

  int get totalBytes => mp4.length + (vtt?.length ?? 0);

  static OfflinePackageManifest parse(Object? value) {
    if (value is! Map<String, dynamic> ||
        !_exactKeys(
          value,
          {
            'schema_version',
            'course_id',
            'lesson_id',
            'content_revision',
            'mobile_content',
            'rights_approved',
            'mp4',
          },
          {'vtt', 'title'},
        ) ||
        value['schema_version'] != 1 ||
        value['course_id'] is! int ||
        value['lesson_id'] is! int ||
        (value['course_id'] as int) <= 0 ||
        (value['lesson_id'] as int) <= 0 ||
        (value['course_id'] as int) > 100000000 ||
        (value['lesson_id'] as int) > 100000000 ||
        value['content_revision'] is! String ||
        !_sha.hasMatch(value['content_revision'] as String) ||
        value['mobile_content'] != true ||
        value['rights_approved'] != true) {
      throw const FormatException('Invalid offline package manifest');
    }
    final title = value['title'];
    if (title != null &&
        (title is! String ||
            title.length > 200 ||
            title.contains(RegExp(r'[\x00-\x1f]')))) {
      throw const FormatException('Invalid public title');
    }
    final mp4 = OfflineAsset.parse(value['mp4'], 'mp4');
    final vtt = value['vtt'] == null
        ? null
        : OfflineAsset.parse(value['vtt'], 'vtt');
    if (mp4.length > maxMp4Bytes ||
        mp4.length + (vtt?.length ?? 0) > maxPackageBytes ||
        (vtt != null && (vtt.url == mp4.url || vtt.sha256 == mp4.sha256))) {
      throw const FormatException('Invalid or duplicate offline assets');
    }
    return OfflinePackageManifest._(
      courseId: value['course_id'] as int,
      lessonId: value['lesson_id'] as int,
      contentRevision: value['content_revision'] as String,
      mobileContent: true,
      rightsApproved: true,
      mp4: mp4,
      vtt: vtt,
      title: title as String?,
    );
  }

  static OfflinePackageManifest fromJson(String source) {
    if (utf8.encode(source).length > 4096) {
      throw const FormatException('Manifest too large');
    }
    return parse(jsonDecode(source));
  }

  Map<String, Object?> toJson() => {
    'schema_version': 1,
    'course_id': courseId,
    'lesson_id': lessonId,
    'content_revision': contentRevision,
    'mobile_content': mobileContent,
    'rights_approved': rightsApproved,
    'mp4': mp4.toJson(),
    if (vtt != null) 'vtt': vtt!.toJson(),
    if (title != null) 'title': title,
  };

  static bool _exactKeys(
    Map<String, dynamic> value,
    Set<String> required,
    Set<String> optional,
  ) =>
      value.keys.toSet().containsAll(required) &&
      value.keys.every(
        (key) => required.contains(key) || optional.contains(key),
      );
}

class OfflineAsset {
  OfflineAsset._(this.url, this.length, this.sha256);
  final Uri url;
  final int length;
  final String sha256;

  static OfflineAsset parse(Object? raw, String extension) {
    if (raw is! Map<String, dynamic> ||
        !OfflinePackageManifest._exactKeys(raw, {
          'url',
          'length',
          'sha256',
        }, {}) ||
        raw['url'] is! String ||
        raw['length'] is! int ||
        (raw['length'] as int) <= 0 ||
        raw['sha256'] is! String ||
        !OfflinePackageManifest._sha.hasMatch(raw['sha256'] as String)) {
      throw const FormatException('Invalid offline asset');
    }
    final source = raw['url'] as String;
    final uri = Uri.tryParse(source);
    if (source.length > 2000 ||
        source.contains('%') ||
        source.contains('\\') ||
        source.contains('..') ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'ead.ipexdesenvolvimento.cloud' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        !OfflinePackageManifest._safePath.hasMatch(uri.path) ||
        !uri.path.endsWith('.$extension') ||
        uri.toString() != source) {
      throw const FormatException('Unapproved IPEX asset URL');
    }
    return OfflineAsset._(uri, raw['length'] as int, raw['sha256'] as String);
  }

  Map<String, Object> toJson() => {
    'url': url.toString(),
    'length': length,
    'sha256': sha256,
  };
}
