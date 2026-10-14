int chatwootReserve() => 0;
bool chatwootSessionCurrent(int lease) => false;
int chatwootOpen(
  String baseUrl,
  String token,
  String supportContactId,
  String name,
  String phone, {
  String? identifierHash,
  int? lease,
  bool Function()? canIdentify,
  void Function()? onOpened,
  void Function()? onError,
  void Function()? onClosed,
  Duration loadTimeout = const Duration(seconds: 20),
}) => 0;
void chatwootClose([int? lease]) {}
bool get chatwootAvailable => false;
