import 'dart:async';

import 'package:flutter_media_view/function/settings/function_settings.dart';
import 'package:flutter_media_view/function/viewer/function_viewer_video_playback.dart';
import 'package:flutter_media_view/function/common/function_common_services.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_format.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_dialogs_aves_confirmation_dialog.dart';
import 'package:flutter_media_view_video/flutter_media_view_video.dart';
import 'package:flutter/material.dart';

class DatabasePlaybackStateHandler extends PlaybackStateHandler {
  static const resumeTimeSaveMinProgress = .05;
  static const resumeTimeSaveMaxProgress = .95;

  @override
  Future<int?> getResumeTime({required int entryId, required BuildContext context}) async {
    final playback = await localMediaDb.loadVideoPlayback(entryId);
    final resumeTime = playback?.resumeTimeMillis ?? 0;
    if (resumeTime == 0) return null;

    // clear on retrieval
    await localMediaDb.removeVideoPlayback({entryId});

    switch (settings.videoResumptionMode) {
      case .never:
        return 0;
      case .ask:
        final l10n = context.l10n;
        final resume = await showConfirmationDialog(
          context: context,
          message: l10n.videoResumeDialogMessage(formatFriendlyDuration(Duration(milliseconds: resumeTime))),
          ok: l10n.videoResumeButtonLabel,
          cancel: l10n.videoStartOverButtonLabel,
        );
        return resume ? resumeTime : 0;
      case .always:
        return resumeTime;
    }
  }

  @override
  Future<void> saveResumeTime({required int entryId, required int position, required double progress}) async {
    if (resumeTimeSaveMinProgress < progress && progress < resumeTimeSaveMaxProgress) {
      await localMediaDb.addVideoPlayback({
        VideoPlaybackRow(
          entryId: entryId,
          resumeTimeMillis: position,
        ),
      });
    } else {
      await localMediaDb.removeVideoPlayback({entryId});
    }
  }
}
