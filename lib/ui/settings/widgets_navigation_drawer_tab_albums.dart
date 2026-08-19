import 'package:flutter_media_view/function/filters/container_album_group.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_buttons_outlined_button.dart';
import 'package:flutter_media_view/ui/common/dialogs_pick_dialogs_album_pick_page.dart';
import 'package:flutter_media_view/ui/filter/widgets_grids_common_enums.dart';
import 'package:flutter_media_view/ui/common/navigation_drawer_tile.dart';
import 'package:flutter_media_view/ui/settings/widgets_navigation_drawer_editor_banner.dart';
import 'package:flutter/material.dart';

class DrawerAlbumTab extends StatefulWidget {
  final List<AlbumBaseFilter> items;

  const DrawerAlbumTab({
    super.key,
    required this.items,
  });

  @override
  State<DrawerAlbumTab> createState() => _DrawerAlbumTabState();
}

class _DrawerAlbumTabState extends State<DrawerAlbumTab> {
  List<AlbumBaseFilter> get items => widget.items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!settings.useTvLayout) ...[
          const DrawerEditorBanner(),
          const Divider(height: 0),
        ],
        Flexible(
          child: ReorderableListView.builder(
            itemBuilder: (context, index) {
              final filter = items[index];
              void onPressed() => setState(() => items.remove(filter));
              return ListTile(
                key: ValueKey(filter.key),
                leading: DrawerFilterIcon(filter: filter),
                title: DrawerFilterTitle(filter: filter),
                trailing: IconButton(
                  icon: const Icon(AIcons.clear),
                  onPressed: onPressed,
                  tooltip: context.l10n.actionRemove,
                ),
                onTap: settings.useTvLayout ? onPressed : null,
              );
            },
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                items.insert(newIndex, items.removeAt(oldIndex));
              });
            },
            shrinkWrap: true,
          ),
        ),
        const Divider(height: 0),
        const SizedBox(height: 8),
        SafeArea(
          child: FmvOutlinedButton(
            icon: const Icon(AIcons.add),
            label: context.l10n.settingsNavigationDrawerAddAlbum,
            onPressed: () async {
              final albumFilter = await pickAlbum(
                context: context,
                moveType: null,
                chipTypes: AlbumChipType.values.toSet(),
                initialGroup: null,
              );
              if (albumFilter == null || items.contains(albumFilter)) return;
              setState(() => items.add(albumFilter));
            },
          ),
        ),
      ],
    );
  }
}
