import 'package:flutter_media_view/function/utils/android_file_utils.dart';
import 'package:flutter_media_view/ui/common/view.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

extension ExtraVolumeRelativeDirectoryView on VolumeRelativeDirectory {
  String getVolumeDescription(BuildContext context) {
    final volume = androidFileUtils.storageVolumes.firstWhereOrNull((volume) => volume.path == volumePath);
    return volume?.getDescription(context) ?? volumePath;
  }
}
