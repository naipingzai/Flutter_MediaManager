import 'package:flutter_media_view/function/entry/function_entry.dart';
import 'package:flutter_media_view/function/entry/function_entry_extensions_location.dart';
import 'package:flutter_media_view/function/settings/function_settings_enums_coordinate_format.dart';
import 'package:flutter_media_view/function/settings/function_settings.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_text.dart';
import 'package:flutter_media_view/ui/viewer/ui_widgets_viewer_overlay_top_details.dart';
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
