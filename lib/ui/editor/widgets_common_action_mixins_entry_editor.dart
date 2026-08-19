import 'dart:async';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_catalog.dart';
import 'package:flutter_media_view/function/entry/extensions_metadata_edition.dart';
import 'package:flutter_media_view/function/entry/extensions_multipage.dart';
import 'package:flutter_media_view/function/entry/extensions_props.dart';
import 'package:flutter_media_view/function/filters/covered_tag.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/filters/placeholder.dart';
import 'package:flutter_media_view/function/metadata/date_modifier.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/function/model/mime_types.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/about/widgets_about_app_ref.dart';
import 'package:flutter_media_view/ui/common/fmv_app.dart';
import 'package:flutter_media_view/ui/collection/widgets_collection_entry_set_action_delegate.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_confirmation_dialog.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';
import 'package:flutter_media_view/ui/editor/widgets_dialogs_entry_editors_edit_date_dialog.dart';
import 'package:flutter_media_view/ui/editor/widgets_dialogs_entry_editors_edit_description_dialog.dart';
import 'package:flutter_media_view/ui/editor/widgets_dialogs_entry_editors_edit_location_dialog.dart';
import 'package:flutter_media_view/ui/editor/widgets_dialogs_entry_editors_edit_rating_dialog.dart';
import 'package:flutter_media_view/ui/editor/widgets_dialogs_entry_editors_remove_metadata_dialog.dart';
import 'package:flutter_media_view/ui/editor/widgets_dialogs_entry_editors_tag_editor_page.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

mixin EntryEditorMixin {
  Future<DateModifier?> selectDateModifier(BuildContext context, Set<FmvEntry> entries, CollectionLens? collection) async {
    if (entries.isEmpty) return null;

    return showFmvDialog<DateModifier>(
      context: context,
      builder: (context) => EditEntryDateDialog(
        entry: entries.first,
        collection: collection,
      ),
      routeSettings: const RouteSettings(name: EditEntryDateDialog.routeName),
    );
  }

  Future<LocationEditActionResult?> selectLocation(BuildContext context, Set<FmvEntry> entries, CollectionLens? collection) async {
    if (entries.isEmpty) return null;

    return showFmvDialog<LocationEditActionResult>(
      context: context,
      builder: (context) => EditEntryLocationDialog(
        entries: entries,
        collection: collection,
      ),
      routeSettings: const RouteSettings(name: EditEntryLocationDialog.routeName),
    );
  }

  Future<Map<DescriptionField, String?>?> selectTitleDescriptionModifier(BuildContext context, Set<FmvEntry> entries) async {
    if (entries.isEmpty) return null;

    final entry = entries.first;
    final initialTitle = entry.catalogMetadata?.xmpTitle ?? '';
    final fields = await metadataFetchService.getOverlayMetadata(entry, {MetadataSyntheticField.description});
    final initialDescription = fields.description ?? '';

    return showFmvDialog<Map<DescriptionField, String?>>(
      context: context,
      builder: (context) => EditEntryTitleDescriptionDialog(
        initialTitle: initialTitle,
        initialDescription: initialDescription,
      ),
      routeSettings: const RouteSettings(name: EditEntryTitleDescriptionDialog.routeName),
    );
  }

  Future<int?> selectRating(BuildContext context, Set<FmvEntry> entries) async {
    if (entries.isEmpty) return null;

    return showFmvDialog<int>(
      context: context,
      builder: (context) => EditEntryRatingDialog(
        entry: entries.first,
      ),
      routeSettings: const RouteSettings(name: EditEntryRatingDialog.routeName),
    );
  }

  Future<Map<FmvEntry, Set<String>>?> selectTags(BuildContext context, Set<FmvEntry> entries) async {
    if (entries.isEmpty) return null;

    final oldTagsByEntry = Map.fromEntries(
      entries.map((v) {
        return MapEntry(v, v.tags.map(TagFilter.new).toSet());
      }),
    );
    final filtersByEntry =
        await Navigator.maybeOf(context)?.push<Map<FmvEntry, Set<CollectionFilter>>>(
          MaterialPageRoute(
            settings: const RouteSettings(name: TagEditorPage.routeName),
            builder: (context) => TagEditorPage(
              tagsByEntry: oldTagsByEntry,
            ),
          ),
        ) ??
        oldTagsByEntry;

    final newTagsByEntry = <FmvEntry, Set<String>>{};
    await Future.forEach(filtersByEntry.entries, (kv) async {
      final entry = kv.key;
      final filters = kv.value;
      newTagsByEntry[entry] = await getTagsFromFilters(filters, entry);
    });

    return newTagsByEntry;
  }

  Future<Set<String>> getTagsFromFilters(Set<CollectionFilter> filters, FmvEntry entry) async {
    final tags = filters.whereType<TagFilter>().map((v) => v.tag).toSet();
    final placeholderTags = await Future.wait(filters.whereType<PlaceholderFilter>().map((v) => v.toTag(entry)));
    tags.addAll(placeholderTags.nonNulls.where((v) => v.isNotEmpty));
    return tags;
  }

  Future<Set<MetadataType>?> selectMetadataToRemove(BuildContext context, Set<FmvEntry> entries) async {
    if (entries.isEmpty) return null;

    final types = await showFmvDialog<Set<MetadataType>>(
      context: context,
      builder: (context) => RemoveEntryMetadataDialog(
        showJpegTypes: entries.any((entry) => entry.mimeType == MimeTypes.jpeg),
      ),
      routeSettings: const RouteSettings(name: RemoveEntryMetadataDialog.routeName),
    );
    if (types == null || types.isEmpty) return null;

    if (entries.any((entry) => entry.isMotionPhoto) && types.contains(MetadataType.xmp)) {
      final l10n = context.l10n;
      if (!await showConfirmationDialog(
        context: context,
        message: l10n.removeEntryMetadataMotionPhotoXmpWarningDialogMessage,
        ok: l10n.applyButtonLabel,
      )) {
        return null;
      }
    }

    return types;
  }

  Future<bool> checkUndatedItems(BuildContext context, Set<FmvEntry> entries) async {
    // make sure entries are catalogued before we check whether they have a metadata date
    await Future.forEach(entries.where((entry) => !entry.isCatalogued), (entry) async {
      await entry.catalog(background: false, force: false, persist: true);
    });

    final undatedItems = entries.where((entry) {
      if (!entry.isCatalogued) return false;
      final dateMillis = entry.catalogMetadata?.dateMillis;
      return dateMillis == null || dateMillis == 0;
    }).toSet();

    if (undatedItems.isNotEmpty) {
      final confirmationDialogDelegate = MoveUndatedConfirmationDialogDelegate();
      final confirmed = await showSkippableConfirmationDialog(
        context: context,
        type: ConfirmationDialog.moveUndatedItems,
        delegate: confirmationDialogDelegate,
        confirmationButtonLabel: context.l10n.continueButtonLabel,
      );
      confirmationDialogDelegate.dispose();
      if (!confirmed) return false;

      if (settings.setMetadataDateBeforeFileOp) {
        final entriesToDate = undatedItems.where((entry) => entry.canEditDate).toSet();
        if (entriesToDate.isNotEmpty) {
          await EntrySetActionDelegate().editDate(
            context,
            entries: entriesToDate,
            modifier: DateModifier.copyField(DateFieldSource.fileModifiedDate),
            showResult: false,
          );
          // recatalog so that the metadata dates are not ignored when best dates are evaluated
          await Future.forEach(entriesToDate, (entry) async {
            await entry.catalog(background: false, force: true, persist: true);
          });
        }
      }
    }
    return true;
  }
}

class MoveUndatedConfirmationDialogDelegate extends ConfirmationDialogDelegate {
  final ValueNotifier<bool> _setMetadataDate = ValueNotifier(false);

  MoveUndatedConfirmationDialogDelegate() {
    _setMetadataDate.value = settings.setMetadataDateBeforeFileOp;
  }

  void dispose() {
    _setMetadataDate.dispose();
  }

  @override
  List<Widget> build(BuildContext context) => [
    Padding(
      padding: const EdgeInsets.all(16) + const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Text(context.l10n.moveUndatedConfirmationDialogMessage)),
          IconButton(
            icon: const Icon(AIcons.help),
            onPressed: () => FmvApp.launchUrl('${AppReference.fmvFaq}#whats-in-a-date'),
            tooltip: 'FAQ',
          ),
        ],
      ),
    ),
    ValueListenableBuilder<bool>(
      valueListenable: _setMetadataDate,
      builder: (context, flag, child) => SwitchListTile(
        value: flag,
        onChanged: (v) => _setMetadataDate.value = v,
        title: Text(context.l10n.moveUndatedConfirmationDialogSetDate),
      ),
    ),
  ];

  @override
  void apply() => settings.setMetadataDateBeforeFileOp = _setMetadataDate.value;
}
