import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/function/entry/extensions_location.dart';
import 'package:fmv/function/settings/enums_coordinate_format.dart';
import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/ui/theme/icons.dart';
import 'package:fmv/ui/theme/text.dart';
import 'package:fmv/ui/viewer/overlay/top_details.dart';
import 'package:decorated_icon/decorated_icon.dart';
import 'package:flutter/material.dart';

class OverlayLocationRow extends AnimatedWidget {
  final FmvEntry entry;

  OverlayLocationRow({
    super.key,
    required this.entry,
  }) : super(listenable: entry.addressChangeNotifier);

  @override
  Widget build(BuildContext context) {
    String? location;
    if (entry.hasAddress) {
      location = entry.shortAddress;
    }
    if (location == null || location.isEmpty) {
      final latLng = entry.latLng;
      if (latLng != null) {
        location = settings.coordinateFormat.format(context, latLng);
      }
    }
    return Row(
      children: [
        DecoratedIcon(AIcons.location, size: ViewerDetailOverlayContent.iconSize, shadows: ViewerDetailOverlayContent.shadows(context)),
        const SizedBox(width: ViewerDetailOverlayContent.iconPadding),
        Expanded(child: Text(location ?? AText.valueNotAvailable)),
      ],
    );
  }
}
