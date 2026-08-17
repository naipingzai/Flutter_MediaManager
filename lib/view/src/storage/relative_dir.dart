import 'package:flutter_media_view/utils/android_file_utils.dart';
import 'package:flutter_media_view/view/view.dart';
import 'package:aves_model/aves_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

extension ExtraVolumeRelativeDirectoryView on VolumeRelativeDirectory {
  String getVolumeDescription(BuildContext context) {
    final volume = androidFileUtils.storageVolumes.firstWhereOrNull((volume) => volume.path == volumePath);
    return volume?.getDescription(context) ?? volumePath;
  }
}
