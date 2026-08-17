import 'package:flutter_media_view/function/function_covers.dart';
import 'package:flutter_media_view/function/function_filters_container_album_group.dart';
import 'package:flutter_media_view/function/function_filters_covered.dart';
import 'package:flutter_media_view/function/function_filters.dart';
import 'package:flutter_media_view/function/function_vaults.dart';
import 'package:flutter_media_view/function/function_common_services.dart';
import 'package:flutter_media_view/ui/ui_theme_colors.dart';
import 'package:flutter_media_view/ui/ui_theme_icons.dart';
import 'package:flutter_media_view/function/function_android_file_utils.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_identity_aves_icons.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class StoredAlbumFilter extends CollectionFilter with CoveredFilter, AlbumBaseFilter {
  static const type = 'album';

  final String album;
  final String? displayName;
  late final EntryPredicate _test;

  // do not include contextual `displayName` to `props`
  @override
  List<Object?> get props => [album, reversed];

  StoredAlbumFilter(this.album, this.displayName, {super.reversed = false}) {
    _test = (entry) => entry.directory == album;
  }

  factory StoredAlbumFilter.fromMap(Map<String, Object?> json) {
    return StoredAlbumFilter(
      json['album'] as String,
      json['uniqueName'] as String?,
      reversed: json['reversed'] as bool? ?? false,
    );
  }

  @override
  Map<String, Object?> toJsonMap() => {
    'type': type,
    'album': album,
    if (displayName != null) 'uniqueName': displayName,
    if (reversed) 'reversed': reversed,
  };

  @override
  EntryPredicate get positiveTest => _test;

  @override
  bool get exclusiveProp => true;

  @override
  String get universalLabel => displayName ?? pContext.split(album).last;

  @override
  String getTooltip(BuildContext context) => isVault ? super.getTooltip(context) : album;

  @override
  Widget? iconBuilder(BuildContext context, double size, {bool allowGenericIcon = true}) {
    return IconUtils.getAlbumIcon(
          context: context,
          albumPath: album,
          size: size,
        ) ??
        (allowGenericIcon ? Icon(AIcons.album, size: size) : null);
  }

  @override
  Future<Color> color(BuildContext context) {
    // custom color has precedence over others, even custom app color
    final customColor = covers.of(this)?.color;
    if (customColor != null) return SynchronousFuture(customColor);

    final colors = context.read<AvesColorsData>();
    // do not use async/await and rely on `SynchronousFuture`
    // to prevent rebuilding of the `FutureBuilder` listening on this future
    final albumType = covers.effectiveAlbumType(album);
    switch (albumType) {
      case .regular:
      case .vault:
        break;
      case .app:
        final appColor = colors.appColor(album);
        if (appColor != null) return appColor;
      case .camera:
        return SynchronousFuture(colors.albumCamera);
      case .download:
        return SynchronousFuture(colors.albumDownload);
      case .screenRecordings:
        return SynchronousFuture(colors.albumScreenRecordings);
      case .screenshots:
        return SynchronousFuture(colors.albumScreenshots);
      case .videoCaptures:
        return SynchronousFuture(colors.albumVideoCaptures);
    }
    return super.color(context);
  }

  @override
  String get category => type;

  // key is expected by test driver
  @override
  String get key => '$type-$reversed-$album';

  StorageVolume? get storageVolume => androidFileUtils.getStorageVolume(album);

  bool get canRename {
    if (isVault) return true;

    // do not allow renaming volume root
    final dir = androidFileUtils.relativeDirectoryFromPath(album);
    return dir != null && dir.relativeDir.isNotEmpty;
  }

  bool get isVault => vaults.isVault(album);
}
