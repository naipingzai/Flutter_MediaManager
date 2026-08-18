import 'package:flutter_media_view/function/locale/function_aves_locale.dart';
import 'package:flutter_media_view/function/common/function_common_services.dart';
import 'package:flutter_media_view/function/utils/function_android_file_utils.dart';
import 'package:flutter_media_view/function/utils/function_file_utils.dart';
import 'package:flutter_media_view/ui/common/ui_view.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_identity_aves_expansion_tile.dart';
import 'package:flutter_media_view/ui/viewer/ui_widgets_viewer_info_common.dart';
import 'package:flutter/material.dart';

class DebugOSStorageSection extends StatefulWidget {
  const DebugOSStorageSection({super.key});

  @override
  State<DebugOSStorageSection> createState() => _DebugOSStorageSectionState();
}

class _DebugOSStorageSectionState extends State<DebugOSStorageSection> with AutomaticKeepAliveClientMixin {
  final Map<String, int?> _freeSpaceByVolume = {};

  @override
  void initState() {
    super.initState();
    androidFileUtils.storageVolumes.forEach((volume) async {
      final byteCount = await storageService.getFreeSpace(volume);
      setState(() => _freeSpaceByVolume[volume.path] = byteCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AvesExpansionTile(
      title: 'OS Storage',
      children: [
        ...androidFileUtils.storageVolumes.expand((v) {
          final freeSpace = _freeSpaceByVolume[v.path];
          return [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(v.path),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: InfoRowGroup(
                info: {
                  'description': v.getDescription(context),
                  'isPrimary': '${v.isPrimary}',
                  'isRemovable': '${v.isRemovable}',
                  'state': v.state,
                  if (freeSpace != null) 'freeSpace': formatFileSize(AvesLocale.ascii, freeSpace),
                },
              ),
            ),
            const Divider(),
          ];
        }),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
