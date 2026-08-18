import 'package:flutter_media_view/function/common/function_common_services.dart';
import 'package:flutter_media_view/function/utils/function_android_file_utils.dart';
import 'package:flutter_media_view/ui/common/ui_view.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_app_bar_crumb_line.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

class ExplorerCrumbLine extends StatelessWidget {
  final VolumeRelativeDirectory? directory;
  final void Function(VolumeRelativeDirectory? combinedPath) onTap;
  final WidgetBuilder? lastCrumbBuilder;

  const ExplorerCrumbLine({
    super.key,
    required this.directory,
    required this.onTap,
    required this.lastCrumbBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return CrumbLine<VolumeRelativeDirectory?>(
      split: _split,
      combine: _combine,
      onTap: onTap,
      lastCrumbBuilder: lastCrumbBuilder,
    );
  }

  List<String> _split(BuildContext context) {
    final _directory = directory;
    if (_directory == null) return [];
    return [
      _directory.getVolumeDescription(context),
      ...pContext.split(_directory.relativeDir),
    ];
  }

  VolumeRelativeDirectory? _combine(BuildContext context, int index) {
    final _directory = directory;
    if (_directory == null) return null;

    final path = pContext.joinAll([
      _directory.volumePath,
      ..._split(context).skip(1).take(index),
    ]);
    return androidFileUtils.relativeDirectoryFromPath(path);
  }
}
