import 'dart:math';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/utils/function_highlight.dart';
import 'package:flutter_media_view/function/model/function_selection.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/fx_sweeper.dart';
import 'package:flutter_media_view/ui/common/grid_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ThumbnailEntryOverlay extends StatelessWidget {
  final FmvEntry entry;

  const ThumbnailEntryOverlay({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final iconBuilder = context.select<GridThemeData, GridThemeIconBuilder>((t) => t.iconBuilder);
    final children = iconBuilder(context, entry);
    if (children.isEmpty) return const SizedBox();
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: children,
      ),
    );
  }
}

class ThumbnailHighlightOverlay extends StatefulWidget {
  final FmvEntry entry;

  const ThumbnailHighlightOverlay({
    super.key,
    required this.entry,
  });

  @override
  State<ThumbnailHighlightOverlay> createState() => _ThumbnailHighlightOverlayState();
}

class _ThumbnailHighlightOverlayState extends State<ThumbnailHighlightOverlay> {
  final ValueNotifier<bool> _highlightedNotifier = ValueNotifier(false);

  FmvEntry get entry => widget.entry;

  static const startAngle = pi * -3 / 4;

  @override
  void dispose() {
    _highlightedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlightInfo = context.watch<HighlightInfo>();
    _highlightedNotifier.value = highlightInfo.contains(entry);
    return Sweeper(
      builder: (context) => Container(
        decoration: BoxDecoration(
          border: Border.fromBorderSide(
            BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: context.select<GridThemeData, double>((t) => t.highlightBorderWidth),
            ),
          ),
        ),
      ),
      toggledNotifier: _highlightedNotifier,
      startAngle: startAngle,
      centerSweep: false,
      onSweepEnd: highlightInfo.clear,
    );
  }
}

class ThumbnailZoomOverlay extends StatelessWidget {
  final VoidCallback? onZoom;

  const ThumbnailZoomOverlay({
    super.key,
    this.onZoom,
  });

  static const alignment = AlignmentDirectional.bottomEnd;

  @override
  Widget build(BuildContext context) {
    final useTvLayout = context.select<GridThemeData, bool>((t) => t.useTvLayout);
    if (useTvLayout) return const SizedBox();

    final duration = context.select<DurationsData, Duration>((v) => v.formTransition);
    final isSelecting = context.select<Selection<FmvEntry>, bool>((selection) => selection.isSelecting);
    final interactiveDimension = context.select<GridThemeData, double>((t) => t.interactiveDimension);
    return AnimatedSwitcher(
      duration: duration,
      child: isSelecting
          ? Align(
              alignment: alignment,
              child: GestureDetector(
                onTap: onZoom,
                // use a `Container` with a dummy color to make it expand
                // so that we can also detect taps around its child
                child: Container(
                  alignment: alignment,
                  padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                  color: Colors.transparent,
                  width: interactiveDimension,
                  height: interactiveDimension,
                  child: Icon(
                    AIcons.showFullscreenArrows,
                    size: context.select<GridThemeData, double>((t) => t.iconSize),
                    color: Colors.white70,
                  ),
                ),
              ),
            )
          : const SizedBox(),
    );
  }
}
