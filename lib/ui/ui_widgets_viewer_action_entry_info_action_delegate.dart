import 'dart:async';
import 'dart:convert';

import 'package:flutter_media_view/app_mode.dart';
import 'package:flutter_media_view/function/function_entry.dart';
import 'package:flutter_media_view/function/function_entry_extensions_info.dart';
import 'package:flutter_media_view/function/function_entry_extensions_metadata_edition.dart';
import 'package:flutter_media_view/function/function_entry_extensions_multipage.dart';
import 'package:flutter_media_view/function/function_entry_extensions_props.dart';
import 'package:flutter_media_view/function/function_filters.dart';
import 'package:flutter_media_view/function/function_media_geotiff.dart';
import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/function/function_source_collection_lens.dart';
import 'package:flutter_media_view/function/function_mime_types.dart';
import 'package:flutter_media_view/function/function_common_services.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_action_mixins_entry_editor.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_action_mixins_feedback.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_action_mixins_permission_aware.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/ui_widgets_dialogs_aves_confirmation_dialog.dart';
import 'package:flutter_media_view/ui/ui_widgets_map_map_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_viewer_action_single_entry_editor.dart';
import 'package:flutter_media_view/ui/ui_widgets_viewer_debug_debug_page.dart';
import 'package:flutter_media_view/ui/ui_widgets_viewer_info_embedded_notifications.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class EntryInfoActionDelegate with FeedbackMixin, PermissionAwareMixin, EntryEditorMixin, SingleEntryEditorMixin {
  final StreamController<ActionEvent<EntryAction>> _eventStreamController = StreamController.broadcast();

  Stream<ActionEvent<EntryAction>> get eventStream => _eventStreamController.stream;

  bool isVisible({
    required AppMode appMode,
    required AvesEntry targetEntry,
    required EntryAction action,
  }) {
    final canWrite = appMode.canEditEntry && !settings.isReadOnly;
    switch (action) {
      // general
      case .editDate:
      case .editLocation:
      case .editTitleDescription:
      case .editRating:
      case .editTags:
      case .removeMetadata:
        return canWrite;
      case .exportMetadata:
        return true;
      // GeoTIFF
      case .showGeoTiffOnMap:
        return appMode.canNavigate && targetEntry.isGeotiff;
      // motion photo
      case .convertMotionPhotoToStillImage:
        return canWrite && targetEntry.isMotionPhoto;
      case .viewMotionPhotoVideo:
        return appMode.canNavigate && targetEntry.isMotionPhoto;
      // debug
      case .debug:
        return !kReleaseMode;
      default:
        return false;
    }
  }

  bool canApply(AvesEntry targetEntry, EntryAction action) {
    switch (action) {
      // general
      case .rotateCCW:
      case .rotateCW:
        return targetEntry.canRotate;
      case .flip:
        return targetEntry.canFlip;
      case .editDate:
        return targetEntry.canEditDate;
      case .editLocation:
        return targetEntry.canEditLocation;
      case .editTitleDescription:
        return targetEntry.canEditTitleDescription;
      case .editRating:
        return targetEntry.canEditRating;
      case .editTags:
        return targetEntry.canEditTags;
      case .removeMetadata:
        return targetEntry.canEdit && targetEntry.isMetadataRemovalSupported;
      case .exportMetadata:
        return !availability.isLocked;
      // GeoTIFF
      case .showGeoTiffOnMap:
        return true;
      // motion photo
      case .convertMotionPhotoToStillImage:
        return targetEntry.canEdit && targetEntry.isXmpEditionSupported;
      case .viewMotionPhotoVideo:
        return true;
      default:
        return false;
    }
  }

  Future<void> onActionSelected(BuildContext context, AvesEntry targetEntry, CollectionLens? collection, EntryAction action) async {
    await reportService.log('$runtimeType handles $action');
    _eventStreamController.add(ActionStartedEvent(action));
    switch (action) {
      // general
      case .editDate:
        await _editDate(context, targetEntry, collection);
      case .editLocation:
        await _editLocation(context, targetEntry, collection);
      case .editTitleDescription:
        await _editTitleDescription(context, targetEntry);
      case .editRating:
        await _editRating(context, targetEntry);
      case .editTags:
        await _editTags(context, targetEntry);
      case .removeMetadata:
        await _removeMetadata(context, targetEntry);
      case .exportMetadata:
        await _exportMetadata(context, targetEntry);
      // GeoTIFF
      case .showGeoTiffOnMap:
        await _showGeoTiffOnMap(context, targetEntry, collection);
      // motion photo
      case .convertMotionPhotoToStillImage:
        await _convertMotionPhotoToStillImage(context, targetEntry);
      case .viewMotionPhotoVideo:
        OpenEmbeddedDataNotification.motionPhotoVideo().dispatch(context);
      // debug
      case .debug:
        _goToDebug(context, targetEntry);
      default:
        break;
    }
    _eventStreamController.add(ActionEndedEvent(action));
  }

  Future<void> _editDate(BuildContext context, AvesEntry targetEntry, CollectionLens? collection) async {
    final modifier = await selectDateModifier(context, {targetEntry}, collection);
    if (modifier == null) return;

    await edit(context, targetEntry, () => targetEntry.editDate(modifier), shouldCheckUndatedItems: false);
  }

  Future<void> _editLocation(BuildContext context, AvesEntry targetEntry, CollectionLens? collection) async {
    final locationByEntry = await selectLocation(context, {targetEntry}, collection);
    if (locationByEntry == null) return;

    if (locationByEntry.containsKey(targetEntry)) {
      await edit(context, targetEntry, () => targetEntry.editLocation(locationByEntry[targetEntry]));
    }
  }

  Future<void> _editTitleDescription(BuildContext context, AvesEntry targetEntry) async {
    final modifier = await selectTitleDescriptionModifier(context, {targetEntry});
    if (modifier == null) return;

    await edit(context, targetEntry, () => targetEntry.editTitleDescription(modifier));
  }

  Future<void> _editRating(BuildContext context, AvesEntry targetEntry) async {
    final rating = await selectRating(context, {targetEntry});
    if (rating == null) return;

    await quickRate(context, targetEntry, rating);
  }

  Future<void> quickRate(BuildContext context, AvesEntry targetEntry, int rating) async {
    if (targetEntry.rating == rating) return;

    await edit(context, targetEntry, () => targetEntry.editRating(rating));
  }

  Future<void> _editTags(BuildContext context, AvesEntry targetEntry) async {
    final tagsByEntry = await selectTags(context, {targetEntry});
    if (tagsByEntry == null) return;

    final newTags = tagsByEntry[targetEntry] ?? targetEntry.tags;
    await _applyTags(context, targetEntry, newTags);
  }

  Future<void> quickTag(BuildContext context, AvesEntry targetEntry, CollectionFilter filter) async {
    final newTags = {
      ...targetEntry.tags,
      ...await getTagsFromFilters({filter}, targetEntry),
    };
    await _applyTags(context, targetEntry, newTags);
  }

  Future<void> _applyTags(BuildContext context, AvesEntry targetEntry, Set<String> newTags) async {
    final currentTags = targetEntry.tags;
    if (newTags.length == currentTags.length && newTags.every(currentTags.contains)) return;

    await edit(context, targetEntry, () => targetEntry.editTags(newTags));
  }

  Future<void> _removeMetadata(BuildContext context, AvesEntry targetEntry) async {
    final types = await selectMetadataToRemove(context, {targetEntry});
    if (types == null) return;

    await edit(context, targetEntry, () => targetEntry.removeMetadata(types));
  }

  Future<void> _exportMetadata(BuildContext context, AvesEntry targetEntry) async {
    final lines = <String>[];
    final padding = ' ' * 2;
    final titledDirectories = await targetEntry.getMetadataDirectories(context);
    titledDirectories.forEach((kv) {
      final title = kv.key;
      final dir = kv.value;

      lines.add('[$title]');
      final dirContent = dir.allTags;
      final tags = dirContent.keys.toList()..sort();
      tags.forEach((tag) {
        final value = dirContent[tag];
        lines.add('$padding$tag: $value');
      });
    });
    final customContent = lines.join('\n');

    final success = await storageService.createFile(
      basename: '${targetEntry.filenameWithoutExtension}-metadata',
      mimeType: MimeTypes.plainText,
      bytes: utf8.encode(customContent),
    );
    if (success != null) {
      if (success) {
        showFeedback(context, FeedbackType.info, context.l10n.genericSuccessFeedback);
      } else {
        showFeedback(context, FeedbackType.warn, context.l10n.genericFailureFeedback);
      }
    }
  }

  Future<void> _convertMotionPhotoToStillImage(BuildContext context, AvesEntry targetEntry) async {
    final l10n = context.l10n;

    if (!await showConfirmationDialog(
      context: context,
      message: l10n.genericDangerWarningDialogMessage,
      ok: l10n.applyButtonLabel,
    )) {
      return;
    }

    await edit(context, targetEntry, targetEntry.removeTrailerVideo);
  }

  Future<void> _showGeoTiffOnMap(BuildContext context, AvesEntry targetEntry, CollectionLens? collection) async {
    final info = await metadataFetchService.getGeoTiffInfo(targetEntry);
    if (info == null) return;

    final mappedGeoTiff = MappedGeoTiff(
      info: info,
      entry: targetEntry,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    if (!mappedGeoTiff.canOverlay) return;

    final baseCollection = collection;
    if (baseCollection == null) return;

    final mapCollection = baseCollection.copyWith(
      listenToSource: true,
      fixedSelection: baseCollection.sortedEntries.where((entry) => entry.hasGps).where((entry) => entry != targetEntry).toList(),
    );
    await Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: MapPage.routeName),
        builder: (context) => MapPage(
          collection: mapCollection,
          overlayEntry: mappedGeoTiff,
        ),
      ),
    );
  }

  void _goToDebug(BuildContext context, AvesEntry targetEntry) {
    Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: ViewerDebugPage.routeName),
        builder: (context) => ViewerDebugPage(entry: targetEntry),
      ),
    );
  }
}
