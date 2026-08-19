import 'package:fmv/function/grouping/common.dart';
import 'package:fmv/function/settings/settings.dart';
import 'package:fmv/ui/common/identity/identity_fmv_expansion_tile.dart';
import 'package:fmv/ui/common/identity/identity_highlight_title.dart';
import 'package:fmv/ui/viewer/info/common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DebugGroupsSection extends StatefulWidget {
  const DebugGroupsSection({super.key});

  @override
  State<DebugGroupsSection> createState() => _DebugGroupsSectionState();
}

class _DebugGroupsSectionState extends State<DebugGroupsSection> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<Settings>(
      builder: (context, settings, child) {
        return FmvExpansionTile(
          title: 'Groups',
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  const HighlightTitle(title: 'Albums (Grouping)'),
                  InfoRowGroup(
                    info: Map.fromEntries(albumGrouping.allGroups.entries.map((kv) => MapEntry(kv.key.toString(), kv.value.toString()))),
                  ),
                  const HighlightTitle(title: 'Albums (Settings)'),
                  InfoRowGroup(
                    info: Map.fromEntries(settings.albumGroups.entries.map((kv) => MapEntry(kv.key.toString(), kv.value.toString()))),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  const HighlightTitle(title: 'Tags (Grouping)'),
                  InfoRowGroup(
                    info: Map.fromEntries(tagGrouping.allGroups.entries.map((kv) => MapEntry(kv.key.toString(), kv.value.toString()))),
                  ),
                  const HighlightTitle(title: 'Tags (Settings)'),
                  InfoRowGroup(
                    info: Map.fromEntries(settings.tagGroups.entries.map((kv) => MapEntry(kv.key.toString(), kv.value.toString()))),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
