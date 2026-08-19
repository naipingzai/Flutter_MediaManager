import 'dart:async';

import 'package:flutter_media_view/core/app_mode.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_catalog.dart';
import 'package:flutter_media_view/function/entry/extensions_location.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/editor/widgets_common_action_mixins_entry_editor.dart';
import 'package:flutter_media_view/ui/common/common_action_mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/common_action_mixins_permission_aware.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

mixin SingleEntryEditorMixin on FeedbackMixin, PermissionAwareMixin, EntryEditorMixin {
  bool _isMainMode(BuildContext context) => context.read<ValueNotifier<AppMode>>().value == .main;

  Future<void> edit(
    BuildContext context,
    FmvEntry targetEntry,
    Future<Set<EntryDataType>> Function() apply, {
    bool shouldCheckUndatedItems = true,
  }) async {
    if (!await checkStoragePermission(context, {targetEntry})) return;

    if (shouldCheckUndatedItems && !await checkUndatedItems(context, {targetEntry})) return;

    // check before applying, because it relies on provider
    // but the widget tree may be disposed if the user navigated away
    final isMainMode = _isMainMode(context);

    final l10n = context.l10n;
    final source = context.read<CollectionSource?>();
    source?.pauseMonitoring();

    final dataTypes = await apply();
    final success = dataTypes.isNotEmpty;
    try {
      if (success) {
        if (isMainMode && source != null) {
          Set<String> obsoleteTags = targetEntry.tags;
          String? obsoleteCountryCode = targetEntry.addressDetails?.countryCode;
          String? obsoleteStateCode = targetEntry.addressDetails?.stateCode;

          await source.refreshEntries({targetEntry}, dataTypes);

          // invalidate filters derived from values before edition
          // this invalidation must happen after the source is refreshed,
          // otherwise filter chips may eagerly rebuild in between with the old state
          if (obsoleteCountryCode != null) {
            source.invalidateCountryFilterSummary(countryCodes: {obsoleteCountryCode});
          }
          if (obsoleteStateCode != null) {
            source.invalidateStateFilterSummary(stateCodes: {obsoleteStateCode});
          }
          if (obsoleteTags.isNotEmpty) {
            source.invalidateTagFilterSummary(tags: obsoleteTags);
          }
        } else {
          const background = false;
          const persist = false;
          await targetEntry.refresh(background: background, persist: persist, dataTypes: dataTypes);
          await targetEntry.catalog(background: background, force: dataTypes.contains(EntryDataType.catalog), persist: persist);
          await targetEntry.locate(
            background: background,
            force: dataTypes.contains(EntryDataType.address),
            geocoderLocale: settings.fmvLocale,
          );
        }
        showFeedback(context, FeedbackType.info, l10n.genericSuccessFeedback);
      } else {
        showFeedback(context, FeedbackType.warn, l10n.genericFailureFeedback);
      }
    } catch (error, stack) {
      await reportService.recordError(error, stack);
    }
    source?.resumeMonitoring();
  }
}
