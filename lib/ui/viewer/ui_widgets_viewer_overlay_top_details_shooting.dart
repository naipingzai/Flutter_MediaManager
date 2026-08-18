import 'package:flutter_media_view/function/metadata/function_metadata_overlay.dart';
import 'package:flutter_media_view/function/settings/function_settings.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_text.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/viewer/ui_widgets_viewer_overlay_top_details.dart';
import 'package:decorated_icon/decorated_icon.dart';
import 'package:flutter/material.dart';

class OverlayShootingRow extends StatelessWidget {
  final OverlayMetadata details;

  const OverlayShootingRow({
    super.key,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final locale = settings.avesLocale;

    final aperture = details.aperture;
    final apertureText = aperture != null ? 'ƒ/${locale.numberFormat('0.0').format(aperture)}' : AText.valueNotAvailable;

    final focalLength = details.focalLength;
    final focalLengthText = focalLength != null ? context.l10n.focalLength(locale.numberFormat('0.#').format(focalLength)) : AText.valueNotAvailable;

    final iso = details.iso;
    final isoText = iso != null ? 'ISO$iso' : AText.valueNotAvailable;

    return Row(
      children: [
        DecoratedIcon(AIcons.shooting, size: ViewerDetailOverlayContent.iconSize, shadows: ViewerDetailOverlayContent.shadows(context)),
        const SizedBox(width: ViewerDetailOverlayContent.iconPadding),
        Expanded(child: Text(apertureText)),
        Expanded(child: Text(details.exposureTime ?? AText.valueNotAvailable)),
        Expanded(child: Text(focalLengthText)),
        Expanded(child: Text(isoText)),
      ],
    );
  }
}
