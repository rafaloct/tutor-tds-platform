class GenUIResponse {
  final String? text;
  final List<Map<String, dynamic>>? components;

  GenUIResponse({this.text, this.components});

  factory GenUIResponse.fromJson(Map<String, dynamic> json) {
    return GenUIResponse(
      text: json['text'],
      components: json['ui'] != null
          ? List<Map<String, dynamic>>.from(json['ui'])
          : null,
    );
  }
}
