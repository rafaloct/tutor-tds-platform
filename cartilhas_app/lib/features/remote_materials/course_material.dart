/// Public metadata pinned by CourseVersion, never a playback grant.
class CourseMaterial {
  const CourseMaterial({
    required this.id,
    required this.kind,
    required this.title,
    this.url,
    this.mediaId,
  });
  final String id;
  final String kind;
  final String title;
  final String? url;
  final String? mediaId;

  factory CourseMaterial.fromJson(Map<String, dynamic> json) {
    final material = CourseMaterial(
      id: json['id'] as String,
      kind: json['kind'] as String,
      title: json['title'] as String,
      url: json['url'] as String?,
      mediaId: json['media_id'] as String?,
    );
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,119}$').hasMatch(material.id) ||
        material.title.trim().isEmpty ||
        material.title.length > 240 ||
        !{'pdf', 'video', 'link'}.contains(material.kind) ||
        (material.kind == 'video'
            ? material.url != null ||
                  material.mediaId == null ||
                  !RegExp(
                    r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,35}$',
                  ).hasMatch(material.mediaId!)
            : material.mediaId != null || !isPublicMaterialUrl(material.url))) {
      throw const FormatException('Material inválido.');
    }
    return material;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    if (url != null) 'url': url,
    if (mediaId != null) 'media_id': mediaId,
  };
  String get kindLabel => switch (kind) {
    'pdf' => 'PDF',
    'video' => 'Vídeo',
    _ => 'Link',
  };
}

bool isPublicMaterialUrl(String? value) {
  if (value == null ||
      value.length > 2000 ||
      RegExp(r'[\s\\]').hasMatch(value)) {
    return false;
  }
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      RegExp(
        r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$',
      ).hasMatch(uri.host) &&
      !{
        'localhost',
        'local',
        'internal',
        'invalid',
        'test',
        'example',
        'home',
        'lan',
        'localdomain',
        'onion',
      }.contains(uri.host.split('.').last) &&
      (!uri.hasPort || uri.port == 443) &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;
}
