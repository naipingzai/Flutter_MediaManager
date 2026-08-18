import 'dart:async';
import 'dart:io';

import 'package:flutter_media_view/app_mode.dart';
import 'package:flutter_media_view/function/entry/function_entry.dart';
import 'package:flutter_media_view/function/entry/function_entry_extensions_favourites.dart';
import 'package:flutter_media_view/function/entry/function_entry_extensions_keys.dart';
import 'package:flutter_media_view/function/entry/function_entry_extensions_multipage.dart';
import 'package:flutter_media_view/function/model/function_favourites.dart';
import 'package:flutter_media_view/function/filters/function_filters_covered_stored_album.dart';
import 'package:flutter_media_view/function/filters/function_filters_trash.dart';
import 'package:flutter_media_view/function/function_highlight.dart';
import 'package:flutter_media_view/function/media/function_multipage.dart';
import 'package:flutter_media_view/function/settings/function_settings.dart';
import 'package:flutter_media_view/function/source/function_source_collection_lens.dart';
import 'package:flutter_media_view/function/source/function_source_collection_source.dart';
import 'package:flutter_media_view/function/model/function_mime_types.dart';
import 'package:flutter_media_view/function/common/function_common_image_op_events.dart';
import 'package:flutter_media_view/function/common/function_common_services.dart';
import 'package:flutter_media_view/function/media/function_media_enums.dart';
import 'package:flutter_media_view/function/media/function_media_media_edit_service.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_durations.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_themes.dart';
import 'package:flutter_media_view/function/utils/function_android_file_utils.dart';
import 'package:flutter_media_view/ui/collection/ui_widgets_collection_collection_page.dart';
import 'package:flutter_media_view/ui/editor/ui_widgets_common_action_mixins_entry_editor.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_action_mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_action_mixins_permission_aware.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_action_mixins_size_aware.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_dialogs_aves_confirmation_dialog.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_dialogs_aves_dialog.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_dialogs_pick_dialogs_album_pick_page.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_dialogs_selection_dialogs_single_selection.dart';
import 'package:flutter_media_view/ui/filter/ui_widgets_filter_grids_common_enums.dart';
import 'package:flutter_media_view/ui/viewer/ui_widgets_viewer_controls_notifications.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

mixin EntryStorageMixin on FeedbackMixin, PermissionAwareMixin, SizeAwareMixin, EntryEditorMixin {
  // returns whether it completed the action (with or without failures)
  Future<bool> doExport(BuildContext context, Set<AvesEntry> targetEntries, EntryConvertOptions options) async {
    final destinationAlbumFilter = await pickAlbum(
      context: context,
      moveType: MoveType.export,
      chipTypes: {AlbumChipType.stored},
      initialGroup: null,
    );
    if (destinationAlbumFilter == null || destinationAlbumFilter is! StoredAlbumFilter) return false;

    final destinationAlbum = destinationAlbumFilter.album;
    if (!await checkStoragePermissionForAlbums(context, {destinationAlbum})) return false;

    if (!await checkFreeSpaceForMove(context, targetEntries, destinationAlbum, MoveType.export)) return false;

    final transientMultiPageInfo = <MultiPageInfo>{};
    final selection = <AvesEntry>{};
    await Future.forEach(targetEntries, (targetEntry) async {
      if (targetEntry.isMultiPage) {
        final multiPageInfo = await targetEntry.getMultiPageInfo();
        if (multiPageInfo != null) {
          transientMultiPageInfo.add(multiPageInfo);
          if (targetEntry.isMotionPhoto) {
            await multiPageInfo.extractMotionPhotoVideo();
          }
          if (multiPageInfo.pageCount > 1) {
            selection.addAll(multiPageInfo.exportEntries);
          }
        }
      } else {
        selection.add(targetEntry);
      }
    });

    final l10n = context.l10n;

    var nameConflictStrategy = NameConflictStrategy.rename;
    final destinationDirectory = Directory(destinationAlbum);
    final destinationExtension = MimeTypes.extensionFor(options.mimeType);
    final names = [
      ...selection.map((v) => '${v.filenameWithoutExtension}$destinationExtension'),
      // do not guard up front based on directory existence,
      // as conflicts could be within moved entries scattered across multiple albums
      if (await destinationDirectory.exists()) ...destinationDirectory.listSync().map((v) => pContext.basename(v.path)),
    ].map((v) => v.toLowerCase()).toList();
    // case insensitive comparison
    final uniqueNames = names.toSet();
    if (uniqueNames.length < names.length) {
      final value = await showAvesDialog<NameConflictStrategy>(
        context: context,
        builder: (context) => AvesSingleSelectionDialog<NameConflictStrategy>(
          initialValue: nameConflictStrategy,
          options: Map.fromEntries(NameConflictStrategy.values.map((v) => MapEntry(v, v.getName(context)))),
          message: l10n.nameConflictDialogSingleSourceMessage,
          confirmationButtonLabel: l10n.continueButtonLabel,
        ),
        routeSettings: const RouteSettings(name: AvesSingleSelectionDialog.routeName),
      );
      if (value == null) return false;
      nameConflictStrategy = value;
    }

    final selectionCount = selection.length;
    final source = context.read<CollectionSource>();
    source.pauseMonitoring();
    await showOpReport<ExportOpEvent>(
      context: context,
      opStream: mediaEditService.export(
        selection,
        options: options,
        destinationAlbum: destinationAlbum,
        nameConflictStrategy: nameConflictStrategy,
      ),
      itemCount: selectionCount,
      onDone: (processed) async {
        final successOps = processed.where((op) => op.success).toSet();
        final exportedOps = successOps.where((op) => !op.skipped && op.newFields[EntryFields.uri] != null).toSet();
        final newUris = exportedOps.map((op) => op.newFields[EntryFields.uri] as String).toSet();
        final isMainMode = context.read<ValueNotifier<AppMode>>().value == .main;

        // check source favourite status
        final favouriteSourceUris = selection.where((entry) => entry.isFavourite).map((entry) => entry.uri).toSet();
        final favouriteNewUris = <String>{};
        exportedOps.forEach((op) {
          final sourceUri = op.uri;
          if (favouriteSourceUris.contains(sourceUri)) {
            final newUri = op.newFields[EntryFields.uri] as String;
            favouriteNewUris.add(newUri);
          }
        });

        source.resumeMonitoring();
        unawaited(
          source.refreshUris(newUris).then((_) {
            // transfer favourite status on exports
            final newFavouriteEntries = source.allEntries.where((entry) => favouriteNewUris.contains(entry.uri)).toSet();
            favourites.add(newFavouriteEntries);
          }),
        );

        // get navigator beforehand because
        // local context may be deactivated when action is triggered after navigation
        final navigator = Navigator.maybeOf(context);
        final showAction = isMainMode && newUris.isNotEmpty
            ? SnackBarAction(
                label: l10n.showButtonLabel,
                onPressed: () {
                  if (navigator != null) {
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: CollectionPage.routeName),
                        builder: (context) => CollectionPage(
                          source: source,
                          filters: {StoredAlbumFilter(destinationAlbum, source.getStoredAlbumDisplayName(context, destinationAlbum))},
                          highlightTest: (entry) => newUris.contains(entry.uri),
                        ),
                      ),
                      (route) => false,
                    );
                  }
                },
              )
            : null;
        final successCount = successOps.length;
        if (successCount < selectionCount) {
          final count = selectionCount - successCount;
          showFeedback(
            context,
            FeedbackType.warn,
            l10n.collectionExportFailureFeedback(count),
            showAction,
          );
        } else {
          showFeedback(
            context,
            FeedbackType.info,
            l10n.genericSuccessFeedback,
            showAction,
          );
        }
      },
    );
    transientMultiPageInfo.forEach((v) => v.dispose());
    return true;
  }

  // returns whether it completed the action (with or without failures)
  Future<bool> doQuickMove(
    BuildContext context, {
    required MoveType moveType,
    required Map<String, Set<AvesEntry>> entriesByDestination,
    bool hideShowAction = false,
    VoidCallback? onSuccess,
  }) async {
    if (moveType == MoveType.move) {
      // skip moving entries to their directory
      entriesByDestination.forEach((destinationAlbum, entries) {
        entries.removeWhere((entry) => entry.directory == destinationAlbum);
      });
      entriesByDestination.removeWhere((_, entries) => entries.isEmpty);
    }

    final entries = entriesByDestination.values.expand((v) => v).toSet();
    final todoCount = entries.length;
    if (todoCount == 0) return true;

    final toBin = moveType == MoveType.toBin;
    final copy = moveType == MoveType.copy;

    // permission for modification at destinations
    final destinationAlbums = entriesByDestination.keys.toSet();
    if (!await checkStoragePermissionForAlbums(context, destinationAlbums)) return false;

    // permission for modification at origins
    final originAlbums = entries.map((e) => e.directory).nonNulls.toSet();
    if ({MoveType.move, MoveType.toBin}.contains(moveType) && !await checkStoragePermissionForAlbums(context, originAlbums, entries: entries)) return false;

    final hasEnoughSpaceByDestination = await Future.wait(
      destinationAlbums.map((destinationAlbum) {
        return checkFreeSpaceForMove(context, entries, destinationAlbum, moveType);
      }),
    );
    if (hasEnoughSpaceByDestination.any((v) => !v)) return false;

    final l10n = context.l10n;
    var nameConflictStrategy = NameConflictStrategy.rename;
    if (!toBin && destinationAlbums.length == 1) {
      final destinationDirectory = Directory(destinationAlbums.single);
      final names = [
        ...entries.map((v) => '${v.filenameWithoutExtension}${v.extension}'),
        // do not guard up front based on directory existence,
        // as conflicts could be within moved entries scattered across multiple albums
        if (await destinationDirectory.exists()) ...destinationDirectory.listSync().map((v) => pContext.basename(v.path)),
      ].map((v) => v.toLowerCase()).toList();
      // case insensitive comparison
      final uniqueNames = names.toSet();
      if (uniqueNames.length < names.length) {
        final value = await showAvesDialog<NameConflictStrategy>(
          context: context,
          builder: (context) => AvesSingleSelectionDialog<NameConflictStrategy>(
            initialValue: nameConflictStrategy,
            options: Map.fromEntries(NameConflictStrategy.values.map((v) => MapEntry(v, v.getName(context)))),
            message: originAlbums.length == 1 ? l10n.nameConflictDialogSingleSourceMessage : l10n.nameConflictDialogMultipleSourceMessage,
            confirmationButtonLabel: l10n.continueButtonLabel,
          ),
          routeSettings: const RouteSettings(name: AvesSingleSelectionDialog.routeName),
        );
        if (value == null) return false;
        nameConflictStrategy = value;
      }
    }

    if ({MoveType.move, MoveType.copy, MoveType.toBin}.contains(moveType) && !await checkUndatedItems(context, entries)) return false;

    // local context may be deactivated when action is triggered (because of navigation or app bar change)
    // so we get the navigator beforehand and rely on its context when appropriate
    final navigator = Navigator.maybeOf(context);
    final navContext = navigator?.context;
    if (navContext == null) return false;

    final appMode = context.read<ValueNotifier<AppMode>?>()?.value;
    final source = context.read<CollectionSource>();
    source.pauseMonitoring();
    final opId = mediaEditService.newOpId;
    await showOpReport<MoveOpEvent>(
      context: context,
      opStream: mediaEditService.move(
        opId: opId,
        entriesByDestination: entriesByDestination,
        copy: copy,
        nameConflictStrategy: nameConflictStrategy,
      ),
      itemCount: todoCount,
      onCancel: () => mediaEditService.cancelFileOp(opId),
      onDone: (processed) async {
        final successOps = processed.where((op) => op.success).toSet();

        // move
        final movedOps = successOps.where((op) => !op.skipped && !op.deleted).toSet();
        final movedEntries = movedOps.map((op) => op.uri).map((uri) => entries.firstWhereOrNull((entry) => entry.uri == uri)).nonNulls.toSet();
        await source.updateAfterMove(
          todoEntries: entries,
          moveType: moveType,
          destinationAlbums: destinationAlbums,
          movedOps: movedOps,
        );

        // delete (when trying to move to bin obsolete entries)
        final deletedOps = successOps.where((op) => op.deleted).toSet();
        final deletedUris = deletedOps.map((op) => op.uri).toSet();
        await source.removeEntries(deletedUris, includeTrash: true);

        source.resumeMonitoring();

        // cleanup
        if ({MoveType.move, MoveType.toBin}.contains(moveType)) {
          await storageService.deleteEmptyRegularDirectories(originAlbums);
        }

        // use navigation context for top-level messaging
        final successCount = successOps.length;
        if (successCount < todoCount) {
          final count = todoCount - successCount;
          showFeedback(
            navContext,
            FeedbackType.warn,
            copy ? l10n.collectionCopyFailureFeedback(count) : l10n.collectionMoveFailureFeedback(count),
          );
        } else {
          final count = movedOps.length;

          SnackBarAction? action;
          if (count > 0 && appMode == .main) {
            if (toBin) {
              if (movedEntries.isNotEmpty) {
                action = SnackBarAction(
                  label: Themes.asButtonLabel(l10n.entryActionRestore),
                  onPressed: () {
                    doMove(
                      navContext,
                      moveType: MoveType.fromBin,
                      entries: movedEntries,
                      hideShowAction: true,
                    );
                  },
                );
              }
            } else if (!hideShowAction) {
              action = SnackBarAction(
                label: l10n.showButtonLabel,
                onPressed: () {
                  _showMovedItems(navContext, destinationAlbums, movedOps);
                },
              );
            }
          }

          if (!toBin || (toBin && settings.confirmAfterMoveToBin)) {
            showFeedback(
              navContext,
              FeedbackType.info,
              copy ? l10n.collectionCopySuccessFeedback(count) : l10n.collectionMoveSuccessFeedback(count),
              action,
            );
          }

          // use local context for handling up the tree
          EntryMovedNotification(moveType, movedEntries).dispatch(context);
          onSuccess?.call();
        }
      },
    );
    return true;
  }

  // returns whether it completed the action (with or without failures)
  Future<bool> doMove(
    BuildContext context, {
    required MoveType moveType,
    required Set<AvesEntry> entries,
    bool hideShowAction = false,
    VoidCallback? onSuccess,
  }) async {
    if (moveType == MoveType.toBin) {
      final l10n = context.l10n;
      if (!await showSkippableConfirmationDialog(
        context: context,
        type: ConfirmationDialog.moveToBin,
        message: l10n.binEntriesConfirmationDialogMessage(entries.length),
        confirmationButtonLabel: l10n.deleteButtonLabel,
      )) {
        return false;
      }
    }

    final entriesByDestination = <String, Set<AvesEntry>>{};
    switch (moveType) {
      case .copy:
      case .move:
      case .export:
        final destinationAlbumFilter = await pickAlbum(
          context: context,
          moveType: moveType,
          chipTypes: {AlbumChipType.stored},
          initialGroup: null,
        );
        if (destinationAlbumFilter == null || destinationAlbumFilter is! StoredAlbumFilter) return false;

        final destinationAlbum = destinationAlbumFilter.album;
        settings.recentDestinationAlbums = settings.recentDestinationAlbums
          ..remove(destinationAlbum)
          ..insert(0, destinationAlbum);
        entriesByDestination[destinationAlbum] = entries;
      case .toBin:
        entriesByDestination[AndroidFileUtils.trashDirPath] = entries;
      case .fromBin:
        groupBy<AvesEntry, String?>(entries, (e) => e.directory).forEach((originAlbum, dirEntries) {
          if (originAlbum != null) {
            entriesByDestination[originAlbum] = dirEntries.toSet();
          }
        });
    }

    return await doQuickMove(
      context,
      moveType: moveType,
      entriesByDestination: entriesByDestination,
      onSuccess: onSuccess,
    );
  }

  // returns whether it completed the action (with or without failures)
  Future<bool> rename(
    BuildContext context, {
    required Map<AvesEntry, String> entriesToNewName,
    required bool persist,
    VoidCallback? onSuccess,
  }) async {
    final entries = entriesToNewName.keys.toSet();
    final todoCount = entries.length;
    assert(todoCount > 0);

    if (!await checkStoragePermission(context, entries)) return false;

    if (!await checkUndatedItems(context, entries)) return false;

    final source = context.read<CollectionSource>();
    source.pauseMonitoring();
    final opId = mediaEditService.newOpId;
    await showOpReport<MoveOpEvent>(
      context: context,
      opStream: mediaEditService.rename(
        opId: opId,
        entriesToNewName: entriesToNewName,
      ),
      itemCount: todoCount,
      onCancel: () => mediaEditService.cancelFileOp(opId),
      onDone: (processed) async {
        final successOps = processed.where((op) => op.success).toSet();
        final movedOps = successOps.where((op) => !op.skipped).toSet();
        await source.updateAfterRename(
          todoEntries: entries,
          movedOps: movedOps,
          persist: persist,
        );
        source.resumeMonitoring();

        final l10n = context.l10n;
        final successCount = successOps.length;
        if (successCount < todoCount) {
          final count = todoCount - successCount;
          showFeedback(context, FeedbackType.warn, l10n.collectionRenameFailureFeedback(count));
        } else {
          final count = movedOps.length;
          showFeedback(context, FeedbackType.info, l10n.collectionRenameSuccessFeedback(count));
          onSuccess?.call();
        }
      },
    );
    return true;
  }

  Future<void> _showMovedItems(
    BuildContext context,
    Set<String> destinationAlbums,
    Set<MoveOpEvent> movedOps,
  ) async {
    final newUris = movedOps.map((op) => op.newFields[EntryFields.uri] as String?).toSet();
    bool highlightTest(AvesEntry entry) => newUris.contains(entry.uri);

    final collection = context.read<CollectionLens?>();
    if (collection == null || collection.filters.any((f) => f is StoredAlbumFilter || f is TrashFilter)) {
      final source = context.read<CollectionSource>();
      final targetFilters = collection?.filters.where((f) => f != TrashFilter.instance).toSet() ?? {};
      // we could simply add the filter to the current collection
      // but navigating makes the change less jarring
      if (destinationAlbums.length == 1) {
        final destinationAlbum = destinationAlbums.single;
        targetFilters.removeWhere((f) => f is StoredAlbumFilter);
        targetFilters.add(StoredAlbumFilter(destinationAlbum, source.getStoredAlbumDisplayName(context, destinationAlbum)));
      }
      unawaited(
        Navigator.maybeOf(context)?.pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: CollectionPage.routeName),
            builder: (context) => CollectionPage(
              source: source,
              filters: targetFilters,
              highlightTest: highlightTest,
            ),
          ),
          (route) => false,
        ),
      );
    } else {
      // track in current page, without navigation
      await Future.delayed(ADurations.highlightScrollInitDelay);
      final targetEntry = collection.sortedEntries.firstWhereOrNull(highlightTest);
      if (targetEntry != null) {
        context.read<HighlightInfo>().trackItem(targetEntry, highlightItem: targetEntry);
      }
    }
  }
}
