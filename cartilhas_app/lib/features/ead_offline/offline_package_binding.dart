import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'offline_http_download.dart';
import 'offline_package_manifest.dart';
import 'offline_package_store.dart';

/// The server adapter must verify all three facts independently: mobile
/// publication, rights and exact revision/asset metadata. No production
/// adapter currently implements this contract, so the default denies release.
abstract class VerifiedOfflineReleaseAuthority {
  Future<bool> verify(OfflinePackageManifest manifest);
}

class DenyOfflineReleaseAuthority implements VerifiedOfflineReleaseAuthority {
  const DenyOfflineReleaseAuthority();
  @override
  Future<bool> verify(OfflinePackageManifest manifest) async => false;
}

Future<OfflinePackageStore> applicationOfflinePackageStore({
  VerifiedOfflineReleaseAuthority authority =
      const DenyOfflineReleaseAuthority(),
  OfflineAssetDownload? download,
  String namespace = 'production',
}) async {
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(namespace)) {
    throw ArgumentError.value(namespace, 'namespace');
  }
  final support = await getApplicationSupportDirectory();
  final root = Directory(
    '${support.path}${Platform.pathSeparator}ead_offline'
    '${Platform.pathSeparator}$namespace',
  );
  return OfflinePackageStore(
    root: root,
    authorize: authority.verify,
    download: download ?? OfflineHttpDownload().call,
  );
}
