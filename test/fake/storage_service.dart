import 'package:flutter_media_view/function/services/storage_service.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:test/fake.dart';

class FakeStorageService extends Fake implements StorageService {
  static const primaryRootAlbum = '/storage/emulated/0';
  static const primaryPath = '$primaryRootAlbum/';
  static const primaryDescription = 'Internal Storage';
  static const removablePath = '/storage/1234-5678/';
  static const removableDescription = 'SD Card';

  @override
  Future<Set<StorageVolume>> getStorageVolumes() => SynchronousFuture({
    const StorageVolume(
      path: primaryPath,
      description: primaryDescription,
      isPrimary: true,
      isRemovable: false,
      state: 'fake',
    ),
    const StorageVolume(
      path: removablePath,
      description: removableDescription,
      isPrimary: false,
      isRemovable: true,
      state: 'fake',
    ),
  });

  @override
  Future<Set<String>> getUntrackedTrashPaths(Iterable<String> knownPaths) => SynchronousFuture({});

  @override
  Future<String> getVaultRoot() => SynchronousFuture('/vault/');
}
