import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/services/intent_service.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/collection/widgets_filter_bar.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_fmv_caption.dart';
import 'package:flutter/material.dart';

class SettingsCollectionTile extends StatelessWidget {
  final Set<CollectionFilter> filters;
  final void Function(Set<CollectionFilter>) onSelection;

  const SettingsCollectionTile({
    super.key,
    required this.filters,
    required this.onSelection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hasSubtitle = filters.isEmpty;

    // size and padding to match `ListTile`
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: (hasSubtitle ? 72.0 : 56.0) + theme.visualDensity.baseSizeAdjustment.dy,
      ),
      child: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        l10n.settingsCollectionTile,
                        // fallback to `ListTile` M3 default style
                        style: theme.listTileTheme.titleTextStyle ?? theme.textTheme.bodyLarge!.copyWith(color: theme.colorScheme.onSurface),
                      ),
                      if (hasSubtitle) FmvCaption(l10n.drawerCollectionAll),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () async {
                      final selection = await IntentService.pickCollectionFilters(filters);
                      if (selection != null) {
                        onSelection(selection);
                      }
                    },
                    icon: const Icon(AIcons.edit),
                  ),
                ],
              ),
            ),
            if (filters.isNotEmpty)
              FilterBar(
                filters: filters,
                interactive: false,
              ),
          ],
        ),
      ),
    );
  }
}
