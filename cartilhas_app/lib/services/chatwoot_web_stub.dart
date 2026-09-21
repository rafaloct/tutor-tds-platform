// Stub para plataformas não-web (Android, iOS)
void chatwootOpen(
  String baseUrl,
  String token,
  String supportContactId,
  String name,
  String phone, {
  String? identifierHash,
}) {}
void chatwootClose() {}
bool get chatwootAvailable => false;
