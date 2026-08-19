import 'dart:async';

import 'package:flutter_media_view/function/filters/container_album_group.dart';
import 'package:flutter_media_view/function/filters/covered_stored_album.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/collection/page.dart';
import 'package:flutter_media_view/ui/common/actions/mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/actions/mixins_vault_aware.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/drawer_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CollectionNavTile extends StatelessWidget with FeedbackMixin, VaultAwareMixin {
  final Widget? leading;
  final Widget title;
  final Widget? trailing;
  final Set<CollectionFilter?>? filters;
  final bool Function() isSelected;

  const CollectionNavTile({
    super.key,
    required this.leading,
    required this.title,
    this.trailing,
    required this.filters,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: ListTile(
        leading: leading,
        title: title,
        trailing: trailing != null
            ? Builder(
                builder: (context) {
                  final trailingColor = IconTheme.of(context).color!.withValues(alpha: .6);
                  return IconTheme.merge(
                    data: IconThemeData(color: trailingColor),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: trailingColor),
                      child: trailing!,
                    ),
                  );
                },
              )
            : null,
        onTap: () => _goToCollection(context),
        selected: context.currentRouteName == CollectionPage.routeName && isSelected(),
      ),
    );
  }

  Future<void> _goToCollection(BuildContext context) async {
    final _filters = filters;
    if (_filters != null) {
      for (final filter in _filters) {
        if (filter != null) {
          if (!await unlockFilter(context, filter)) return;
        }
      }
    }

    Navigator.maybeOf(context)?.pop();
    unawaited(
      Navigator.maybeOf(context)?.pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: CollectionPage.routeName),
          builder: (context) => CollectionPage(
            source: context.read<CollectionSource>(),
            filters: _filters,
          ),
        ),
        (route) => false,
      ),
    );
  }
}

class AlbumNavTile extends StatelessWidget {
  final AlbumBaseFilter filter;
  final bool Function() isSelected;

  const AlbumNavTile({
    super.key,
    required this.filter,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final _filter = filter;
    final storageVolume = _filter is StoredAlbumFilter ? _filter.storageVolume : null;
    return CollectionNavTile(
      leading: DrawerFilterIcon(filter: _filter),
      title: DrawerFilterTitle(filter: _filter),
      trailing: storageVolume?.isRemovable ?? false
          ? const Icon(
              AIcons.storageCard,
              size: 16,
            )
          : null,
      filters: {_filter},
      isSelected: isSelected,
    );
  }
}
