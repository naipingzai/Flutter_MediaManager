import 'package:flutter_media_view/function/function_metadata_overlay.dart';
import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/theme/text.dart';
import 'package:flutter_media_view/ui/widgets/common/extensions/build_context.dart';
import 'package:flutter_media_view/ui/widgets/viewer/overlay/top/details/details.dart';
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
