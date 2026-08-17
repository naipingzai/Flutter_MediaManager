import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/function/function_bursts.dart';
import 'package:flutter_media_view/ui/theme/colors.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/widgets/common/extensions/build_context.dart';
import 'package:flutter_media_view/ui/widgets/settings/common/tile_leading.dart';
import 'package:flutter_media_view/ui/widgets/settings/common/tiles.dart';
import 'package:flutter_media_view/ui/widgets/settings/settings_definition.dart';
import 'package:flutter_media_view/ui/widgets/settings/thumbnails/collection_actions_editor_page.dart';
import 'package:flutter_media_view/ui/widgets/settings/thumbnails/overlay_page.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ThumbnailsSection extends SettingsSection {
  @override
  String get key => 'thumbnails';

  @override
  Widget icon(BuildContext context) => SettingsTileLeading(
    icon: AIcons.thumbnails,
    color: context.select<AvesColorsData, Color>((v) => v.thumbnails),
  );

  @override
  String title(BuildContext context) => context.l10n.settingsThumbnailSectionTitle;

  @override
  Future<List<SettingsTile>> tiles(BuildContext context) => Future.value([
    if (!settings.useTvLayout) SettingsTileCollectionQuickActions(),
    SettingsTileThumbnailOverlay(),
    SettingsTileBurstPatterns(),
  ]);
}

class SettingsTileCollectionQuickActions extends SettingsTile {
  @override
  List<String> get settingKeys => CollectionActionEditorPage.settingKeys;

  @override
  String title(BuildContext context) => context.l10n.settingsCollectionQuickActionsTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    routeName: CollectionActionEditorPage.routeName,
    builder: (context) => const CollectionActionEditorPage(),
  );
}

class SettingsTileThumbnailOverlay extends SettingsTile {
  @override
  List<String> get settingKeys => ThumbnailOverlayPage.settingKeys;

  @override
  String title(BuildContext context) => context.l10n.settingsThumbnailOverlayTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    routeName: ThumbnailOverlayPage.routeName,
    builder: (context) => const ThumbnailOverlayPage(),
  );
}

class SettingsTileBurstPatterns extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.collectionBurstPatternsKey];

  @override
  String title(BuildContext context) => context.l10n.settingsCollectionBurstPatternsTile;

  @override
  Widget build(BuildContext context) => SettingsMultiSelectionListTile<String>(
    values: BurstPatterns.options,
    getName: (context, v) => BurstPatterns.getName(v),
    selector: (context, s) => s.collectionBurstPatterns,
    onSelection: (v) => settings.collectionBurstPatterns = v,
    tileTitle: title(context),
    noneSubtitle: context.l10n.settingsCollectionBurstPatternsNone,
    optionSubtitleBuilder: (value) => '${Unicode.FSI}${BurstPatterns.getExample(value)}${Unicode.PDI}',
  );
}
