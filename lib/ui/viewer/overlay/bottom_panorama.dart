import 'dart:async';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/common/actions/mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/identity/identity_buttons_overlay_button.dart';
import 'package:flutter_media_view/ui/viewer/overlay/bottom.dart';
import 'package:flutter_media_view/ui/viewer/panorama_page.dart';
import 'package:flutter/material.dart';

class PanoramaOverlay extends StatelessWidget with FeedbackMixin {
  final FmvEntry entry;
  final Animation<double> scale;

  const PanoramaOverlay({
    super.key,
    required this.entry,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: ViewerBottomOverlay.actionsDirection,
      children: [
        const Spacer(),
        ScalingOverlayTextButton(
          scale: scale,
          onPressed: () async {
            final info = await metadataFetchService.getPanoramaInfo(entry);
            if (info == null) {
              showFeedback(context, FeedbackType.warn, context.l10n.genericFailureFeedback);
            }
            if (info != null) {
              unawaited(
                Navigator.maybeOf(context)?.push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: PanoramaPage.routeName),
                    builder: (context) => PanoramaPage(
                      entry: entry,
                      info: info,
                    ),
                  ),
                ),
              );
            }
          },
          child: Text(context.l10n.viewerOpenPanoramaButtonLabel),
        ),
      ],
    );
  }
}
