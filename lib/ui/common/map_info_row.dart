import 'package:fmv/function/entry/entry.dart';
import 'package:fmv/ui/common/map_address_row.dart';
import 'package:fmv/ui/common/map_date_row.dart';
import 'package:fmv_map/flutter_media_view_map.dart';
import 'package:flutter/material.dart';

class MapInfoRow extends StatelessWidget {
  final ValueNotifier<FmvEntry?> entryNotifier;

  static const double iconPadding = 8.0;
  static const double _interRowPadding = 2.0;

  const MapInfoRow({
    super.key,
    required this.entryNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FmvEntry?>(
      valueListenable: entryNotifier,
      builder: (context, entry, child) {
        final isPortrait = MediaQuery.orientationOf(context) == Orientation.portrait;
        final content = isPortrait
            ? [
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: .start,
                    children: [
                      MapAddressRow(entry: entry),
                      const SizedBox(height: _interRowPadding),
                      MapDateRow(entry: entry),
                    ],
                  ),
                ),
              ]
            : [
                MapDateRow(entry: entry),
                Expanded(
                  child: MapAddressRow(entry: entry),
                ),
              ];

        return Opacity(
          opacity: entry != null ? 1 : 0,
          child: Row(
            mainAxisSize: .min,
            children: [
              const SizedBox(width: iconPadding),
              const DotMarker(),
              ...content,
            ],
          ),
        );
      },
    );
  }

  static double getIconSize(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return textScaler.scale(16);
  }
}
