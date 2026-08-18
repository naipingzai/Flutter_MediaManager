import 'dart:convert';

import 'package:flutter_media_view/function/filters/covered_stored_album.dart';
import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/locale/locales.dart';
import 'package:flutter_media_view/function/model/mime_types.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/common_action_mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/common_basic_insets.dart';
import 'package:flutter_media_view/ui/common/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/common_extensions_media_query.dart';
import 'package:flutter_media_view/ui/filter/widgets_common_identity_fmv_filter_chip.dart';
import 'package:flutter_media_view/ui/filter/widgets_stats_filter_table.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_controls_notifications.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class StatsTopPage<T extends Comparable> extends StatelessWidget with FeedbackMixin {
  static const routeName = '/collection/stats/top';

  final String title;
  final int totalEntryCount;
  final Map<T, int> entryCountMap;
  final CollectionFilter Function(T key) filterBuilder;
  final bool sortByCount;
  final AFilterCallback onFilterSelection;

  const StatsTopPage({
    super.key,
    required this.title,
    required this.totalEntryCount,
    required this.entryCountMap,
    required this.filterBuilder,
    required this.sortByCount,
    required this.onFilterSelection,
  });

  @override
  Widget build(BuildContext context) {
    return FmvScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !settings.useTvLayout,
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(AIcons.fileExport),
            onPressed: () => _export(context),
            tooltip: context.l10n.settingsActionExport,
          ),
        ],
      ),
      body: GestureAreaProtectorStack(
        child: SafeArea(
          bottom: false,
          child: Builder(
            builder: (context) {
              return NotificationListener<SelectFilterNotification>(
                onNotification: (notification) {
                  onFilterSelection(notification.filter);
                  return true;
                },
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8) +
                      EdgeInsets.only(
                        bottom: context.select<MediaQueryData, double>((mq) => mq.effectiveBottomPadding),
                      ),
                  child: FilterTable(
                    totalEntryCount: totalEntryCount,
                    entryCountMap: entryCountMap,
                    filterBuilder: filterBuilder,
                    sortByCount: sortByCount,
                    maxRowCount: null,
                    onFilterSelection: onFilterSelection,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final sortedEntries = entryCountMap.entries.toList();
    if (sortByCount) {
      sortedEntries.sort((kv1, kv2) {
        final c = kv2.value.compareTo(kv1.value);
        return c != 0 ? c : kv1.key.compareTo(kv2.key);
      });
    }

    final csvContent = csv.encode([
      [title, '#'],
      ...sortedEntries.map((kv) {
        final filter = filterBuilder(kv.key);
        final count = kv.value;

        String label;
        switch (filter) {
          case StoredAlbumFilter _:
            label = filter.album;
          default:
            label = filter.getLabel(context);
        }
        return [label, count];
      }),
    ]);

    const mimeType = MimeTypes.csv;
    final date = DateFormat('yyyyMMdd_HHmmss', kAsciiLocale).format(DateTime.now());
    final success = await storageService.createFile(
      basename: 'aves-stats-$date',
      mimeType: mimeType,
      bytes: utf8.encode(csvContent),
    );
    if (success != null) {
      if (success) {
        showFeedback(context, FeedbackType.info, context.l10n.genericSuccessFeedback);
      } else {
        showFeedback(context, FeedbackType.warn, context.l10n.genericFailureFeedback);
      }
    }
  }
}
