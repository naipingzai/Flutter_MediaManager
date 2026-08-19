import 'dart:async';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_keys.dart';
import 'package:flutter_media_view/function/model/mime_types.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/common/actions/common_action_mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/behaviour/common_behaviour_routes.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';
import 'package:flutter_media_view/ui/viewer/entry_viewer_page.dart';
import 'package:flutter_media_view/ui/viewer/info_embedded_notifications.dart';
import 'package:flutter/material.dart';

class EmbeddedDataOpener extends StatelessWidget with FeedbackMixin {
  final bool enabled;
  final FmvEntry entry;
  final Widget child;

  const EmbeddedDataOpener({
    super.key,
    required this.enabled,
    required this.entry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<OpenEmbeddedDataNotification>(
      onNotification: (notification) {
        if (enabled) {
          _openEmbeddedData(context, notification);
          return true;
        }
        return false;
      },
      child: child,
    );
  }

  Future<void> _openEmbeddedData(BuildContext context, OpenEmbeddedDataNotification notification) async {
    late Map fields;
    switch (notification.source) {
      case .googleDevice:
        fields = await embeddedDataService.extractGoogleDeviceItem(entry, notification.dataUri!);
      case .motionPhotoVideo:
        fields = await embeddedDataService.extractMotionPhotoVideo(entry);
      case .mpf:
        fields = await embeddedDataService.extractJpegMpfItem(entry, notification.mpfId!);
      case .videoCover:
        fields = await embeddedDataService.extractVideoEmbeddedPicture(entry);
      case .xmp:
        fields = await embeddedDataService.extractXmpDataProp(entry, notification.props, notification.mimeType);
    }
    FmvEntry.normalizeMimeTypeFields(fields);
    final mimeType = fields[EntryFields.mimeType] as String?;
    final uri = fields[EntryFields.uri] as String?;
    if (mimeType == null || uri == null) {
      showFeedback(context, FeedbackType.warn, context.l10n.viewerInfoOpenEmbeddedFailureFeedback);
      return;
    }

    if (!MimeTypes.isImage(mimeType) && !MimeTypes.isVideo(mimeType)) {
      // open with another app
      unawaited(
        appService.open(uri, mimeType, forceChooser: true).then((success) {
          if (!success) {
            // fallback to sharing, so that the file can be saved somewhere
            appService.shareSingle(uri, mimeType).then((success) {
              if (!success) showNoMatchingAppDialog(context);
            });
          }
        }),
      );
      return;
    }

    _openTempEntry(context, FmvEntry.fromMap(fields));
  }

  void _openTempEntry(BuildContext context, FmvEntry tempEntry) {
    Navigator.maybeOf(context)?.push(
      TransparentMaterialPageRoute(
        settings: const RouteSettings(name: EntryViewerPage.routeName),
        pageBuilder: (context, a, sa) => EntryViewerPage(
          initialEntry: tempEntry,
        ),
      ),
    );
  }
}
