class AuthUser {
  const AuthUser({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final String role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final role = json['role'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        role is! String ||
        role.isEmpty) {
      throw const FormatException('Usuário de autenticação inválido.');
    }
    return AuthUser(id: id, name: name, role: role);
  }
}

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  Map<String, String> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
  };

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw const FormatException('Tokens de autenticação inválidos.');
    }
    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }
}

class AuthSession {
  const AuthSession({required this.user, required this.tokens});

  final AuthUser user;
  final AuthTokens tokens;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('Sessão de autenticação inválida.');
    }
    return AuthSession(
      user: AuthUser.fromJson(user),
      tokens: AuthTokens.fromJson(json),
    );
  }
}
