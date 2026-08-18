import 'package:flutter_media_view/function/function_covers.dart';
import 'package:flutter_media_view/function/function_entry.dart';
import 'package:flutter_media_view/function/function_source_collection_source.dart';
import 'package:flutter_media_view/function/function_source_section_keys.dart';
import 'package:flutter_media_view/ui/ui_theme_icons.dart';
import 'package:flutter_media_view/function/function_android_file_utils.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_grid_header.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_identity_aves_icons.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

class AlbumSectionHeader extends StatelessWidget {
  final String? directory, albumName;
  final bool selectable;

  const AlbumSectionHeader({
    super.key,
    required this.directory,
    required this.albumName,
    required this.selectable,
  });

  @override
  Widget build(BuildContext context) {
    Widget? albumIcon;
    final _directory = directory;
    if (_directory != null) {
      albumIcon = IconUtils.getAlbumIcon(context: context, albumPath: _directory);
      if (albumIcon != null) {
        albumIcon = RepaintBoundary(
          child: albumIcon,
        );
      }
    }
    return SectionHeader<AvesEntry>(
      sectionKey: EntryAlbumSectionKey(_directory),
      leading: albumIcon,
      title: albumName ?? context.l10n.sectionUnknown,
      trailing: _directory != null && androidFileUtils.isOnRemovableStorage(_directory)
          ? const Icon(
              AIcons.storageCard,
              size: 16,
              color: Color(0xFF757575),
            )
          : null,
      selectable: selectable,
    );
  }

  static double getPreferredHeight(BuildContext context, double maxWidth, CollectionSource source, EntryAlbumSectionKey sectionKey) {
    final directory = sectionKey.directory ?? context.l10n.sectionUnknown;
    return SectionHeader.getPreferredHeight(
      context: context,
      maxWidth: maxWidth,
      title: source.getStoredAlbumDisplayName(context, directory),
      hasLeading: covers.effectiveAlbumType(directory) != AlbumType.regular,
      hasTrailing: androidFileUtils.isOnRemovableStorage(directory),
    );
  }
}
