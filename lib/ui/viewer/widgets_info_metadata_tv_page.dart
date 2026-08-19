import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/behaviour/common_behaviour_intents.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/navigation_tv_rail.dart';
import 'package:flutter_media_view/ui/viewer/widgets_info_metadata_dir.dart';
import 'package:flutter_media_view/ui/viewer/widgets_info_metadata_dir_tile.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvMetadataPage extends StatefulWidget {
  static const routeName = '/info/metadata';

  final FmvEntry entry;
  final Map<String, MetadataDirectory> metadata;

  const TvMetadataPage({
    super.key,
    required this.entry,
    required this.metadata,
  });

  @override
  State<TvMetadataPage> createState() => _TvMetadataPageState();
}

class _TvMetadataPageState extends State<TvMetadataPage> {
  final ValueNotifier<int> _railIndexNotifier = ValueNotifier(0);
  final FocusNode _railFocusNode = FocusNode();
  final ScrollController _detailsScrollController = ScrollController();

  Map<String, MetadataDirectory> get metadata => widget.metadata;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _railFocusNode.children.firstOrNull?.requestFocus();
    });
  }

  @override
  void dispose() {
    _railIndexNotifier.dispose();
    _railFocusNode.dispose();
    _detailsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FmvScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.l10n.viewerInfoPageTitle),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: _railIndexNotifier,
        builder: (context, selectedIndex, child) {
          final titles = metadata.keys.toList();
          final selectedDir = metadata[titles[selectedIndex]];
          if (selectedDir == null) return const SizedBox();

          final rail = NavigationRail(
            extended: true,
            destinations: titles.mapIndexed((i, title) {
              final dir = metadata[titles[i]]!;
              final color = MetadataDirTile.getTitleColor(context, dir);
              return NavigationRailDestination(
                icon: Icon(AIcons.circle, fill: 1, color: color),
                label: Text(title),
              );
            }).toList(),
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _railIndexNotifier.value = index,
            minExtendedWidth: TvRail.minExtendedWidth,
          );

          return SafeArea(
            child: Row(
              crossAxisAlignment: .start,
              children: [
                const SizedBox(width: 16),
                Focus(
                  focusNode: _railFocusNode,
                  skipTraversal: true,
                  canRequestFocus: false,
                  child: SingleChildScrollView(
                    child: IntrinsicHeight(
                      child: rail,
                    ),
                  ),
                ),
                Expanded(
                  child: FocusableActionDetector(
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.arrowUp): ScrollIntent(direction: AxisDirection.up, type: ScrollIncrementType.page),
                      SingleActivator(LogicalKeyboardKey.arrowDown): ScrollIntent(direction: AxisDirection.down, type: ScrollIncrementType.page),
                    },
                    actions: {
                      ScrollIntent: ScrollControllerAction(scrollController: _detailsScrollController),
                    },
                    child: SingleChildScrollView(
                      controller: _detailsScrollController,
                      padding: const EdgeInsets.all(16),
                      child: MetadataDirTileBody(
                        entry: widget.entry,
                        dir: selectedDir,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
