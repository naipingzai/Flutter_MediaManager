import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraStorageVolumeView on StorageVolume {
  String getDescription(BuildContext? context) {
    if (description != null) return description!;
    // ideally, the context should always be provided, but in some cases (e.g. album comparison),
    // this would require numerous additional methods to have the context as argument
    // for such a minor benefit: fallback volume description on Android < N
    final l10n = context?.l10n;
    if (isPrimary) return l10n?.storageVolumeDescriptionFallbackPrimary ?? 'Internal Storage';
    return l10n?.storageVolumeDescriptionFallbackNonPrimary ?? 'SD card';
  }
}
