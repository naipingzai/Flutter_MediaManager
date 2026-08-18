import 'package:flutter_media_view_map/src/theme.dart';
import 'package:flutter_media_view_ui/flutter_media_view_ui.dart';
import 'package:flutter/material.dart';

class DotMarker extends StatelessWidget {
  const DotMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return const AvesDot(
      diameter: MapThemeData.markerDotDiameter,
      outerBorderWidth: MapThemeData.markerOuterBorderWidth,
      innerBorderWidth: MapThemeData.markerInnerBorderWidth,
      getOuterBorderColor: MapThemeData.markerThemedOuterBorderColor,
      getInnerBorderColor: MapThemeData.markerThemedInnerBorderColor,
    );
  }
}
