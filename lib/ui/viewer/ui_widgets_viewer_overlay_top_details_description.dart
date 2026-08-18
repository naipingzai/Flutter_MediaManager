import 'package:flutter_media_view/ui/theme/ui_theme_icons.dart';
import 'package:flutter_media_view/ui/viewer/ui_widgets_viewer_overlay_top_details.dart';
import 'package:decorated_icon/decorated_icon.dart';
import 'package:flutter/material.dart';

class OverlayDescriptionRow extends StatelessWidget {
  final String description;

  const OverlayDescriptionRow({
    super.key,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: ViewerDetailOverlayContent.iconPadding),
              child: DecoratedIcon(
                AIcons.description,
                size: ViewerDetailOverlayContent.iconSize,
                shadows: ViewerDetailOverlayContent.shadows(context),
              ),
            ),
          ),
          TextSpan(text: description),
        ],
      ),
    );
  }
}
