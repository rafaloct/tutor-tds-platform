/// Public inbox settings. Authentication and personal identity are separate.
class ChatwootConfig {
  factory ChatwootConfig({
    required String baseUrl,
    required String websiteToken,
  }) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.hasPort && (uri.port < 1 || uri.port > 65535)) ||
        baseUrl.split('://').last.split('/').first.endsWith(':') ||
        baseUrl.split('://').last.split('/').first.contains('@') ||
        baseUrl.contains('%') ||
        baseUrl.contains('\\') ||
        RegExp(r'\s').hasMatch(baseUrl) ||
        !_publicHost(uri.host) ||
        !RegExp(r'^(?:/[A-Za-z0-9._~-]+)*/?$').hasMatch(uri.path) ||
        baseUrl
            .split('/')
            .any((segment) => segment == '.' || segment == '..') ||
        !RegExp(r'^[A-Za-z0-9_-]{6,256}$').hasMatch(websiteToken)) {
      throw const FormatException('Invalid public support configuration.');
    }
    final normalized = uri.replace(
      path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
    );
    return ChatwootConfig._(normalized.toString(), websiteToken);
  }

  const ChatwootConfig._(this.baseUrl, this.websiteToken);

  factory ChatwootConfig.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.length != 2 ||
        value['base_url'] is! String ||
        value['website_token'] is! String) {
      throw const FormatException('Invalid public support configuration.');
    }
    return ChatwootConfig(
      baseUrl: value['base_url'] as String,
      websiteToken: value['website_token'] as String,
    );
  }

  final String baseUrl;
  final String websiteToken;

  static bool _publicHost(String raw) {
    final host = raw.toLowerCase();
    if (host.contains(':')) {
      // Match the API's global, nonreserved unicast policy after expanding
      // equivalent textual IPv6 forms (including zero-padded groups).
      var address = host.replaceAll('[', '').replaceAll(']', '');
      if (address.contains('.')) {
        final tailStart = address.lastIndexOf(':') + 1;
        final parts = address.substring(tailStart).split('.');
        if (parts.length != 4) return false;
        final octets = <int>[];
        for (final part in parts) {
          final octet = int.tryParse(part);
          if (octet == null ||
              octet < 0 ||
              octet > 255 ||
              part != octet.toString()) {
            return false;
          }
          octets.add(octet);
        }
        final high = ((octets[0] << 8) | octets[1]).toRadixString(16);
        final low = ((octets[2] << 8) | octets[3]).toRadixString(16);
        address = '${address.substring(0, tailStart)}$high:$low';
      }
      final halves = address.split('::');
      List<int> words(String value) => value.isEmpty
          ? <int>[]
          : value.split(':').map((word) => int.parse(word, radix: 16)).toList();
      final left = words(halves.first);
      final right = halves.length == 2 ? words(halves.last) : <int>[];
      final groups = halves.length == 2
          ? [
              ...left,
              ...List<int>.filled(8 - left.length - right.length, 0),
              ...right,
            ]
          : left;
      if (groups.length != 8 ||
          groups.first < 0x2000 ||
          groups.first > 0x3fff) {
        return false;
      }
      if (groups[0] == 0x2002 ||
          (groups[0] == 0x2001 && groups[1] == 0x0db8) ||
          (groups[0] == 0x3fff && groups[1] < 0x1000)) {
        return false;
      }
      if (groups[0] == 0x2001 && groups[1] < 0x0200) {
        return groups[1] == 3 ||
            (groups[1] == 4 && groups[2] == 0x112) ||
            (groups[1] >= 0x20 && groups[1] <= 0x3f) ||
            (groups[1] == 1 &&
                groups.sublist(2, 7).every((word) => word == 0) &&
                (groups[7] == 1 || groups[7] == 2));
      }
      return true;
    }
    if (RegExp(r'^[0-9.]+$').hasMatch(host)) {
      final parts = host.split('.');
      if (parts.length != 4) return false;
      final bytes = <int>[];
      for (final part in parts) {
        final byte = int.tryParse(part);
        if (byte == null || byte > 255 || part != byte.toString()) return false;
        bytes.add(byte);
      }
      final a = bytes[0], b = bytes[1], c = bytes[2], d = bytes[3];
      return !(a == 0 ||
          a == 10 ||
          a == 127 ||
          a >= 224 ||
          (a == 100 && b >= 64 && b <= 127) ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 168) ||
          (a == 192 && b == 0 && c == 0 && d != 9 && d != 10) ||
          (a == 192 && b == 0 && c == 2) ||
          (a == 198 && (b == 18 || b == 19)) ||
          (a == 198 && b == 51 && c == 100) ||
          (a == 203 && b == 0 && c == 113));
    }
    final labels = host.split('.');
    return host.length <= 253 &&
        labels.length >= 2 &&
        RegExp(r'^[a-z][a-z0-9-]{1,62}$').hasMatch(labels.last) &&
        !const [
          'local',
          'localhost',
          'localdomain',
          'internal',
          'home',
          'lan',
          'test',
          'invalid',
          'example',
        ].contains(labels.last) &&
        host != 'home.arpa' &&
        !host.endsWith('.home.arpa') &&
        labels.every(
          (label) =>
              RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(label),
        );
  }
}
