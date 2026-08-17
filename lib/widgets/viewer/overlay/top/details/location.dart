import 'package:flutter_media_view/model/entry/entry.dart';
import 'package:flutter_media_view/model/entry/extensions/location.dart';
import 'package:flutter_media_view/model/settings/enums/coordinate_format.dart';
import 'package:flutter_media_view/model/settings/settings.dart';
import 'package:flutter_media_view/theme/icons.dart';
import 'package:flutter_media_view/theme/text.dart';
import 'package:flutter_media_view/widgets/viewer/overlay/top/details/details.dart';
import 'package:decorated_icon/decorated_icon.dart';
import 'package:flutter/material.dart';

class OverlayLocationRow extends AnimatedWidget {
  final AvesEntry entry;

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
