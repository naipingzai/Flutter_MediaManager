import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/ui/common/fx_borders.dart';
import 'package:flutter_media_view/ui/common/grid_overlay.dart';
import 'package:flutter_media_view/ui/common/grid_sections_mosaic_section_layout_builder.dart';
import 'package:flutter_media_view/ui/common/thumbnails/common_thumbnail_image.dart';
import 'package:flutter_media_view/ui/common/thumbnails/common_thumbnail_notifications.dart';
import 'package:flutter_media_view/ui/common/thumbnails/common_thumbnail_overlay.dart';
import 'package:flutter/material.dart';

class DecoratedThumbnail extends StatelessWidget {
  final FmvEntry entry;
  final double tileExtent;
  final ValueNotifier<bool>? cancellableNotifier;
  final bool isMosaic, selectable, highlightable;
  final Object? Function()? heroTagger;
  final HeroPlaceholderBuilder? heroPlaceholderBuilder;
  final TransitionBuilder? imageDecorator;

  static Color borderColor(BuildContext context) => Theme.of(context).dividerColor;

  static double borderWidth(BuildContext context) => FmvBorder.straightBorderWidth(context);

  const DecoratedThumbnail({
    super.key,
    required this.entry,
    required this.tileExtent,
    this.cancellableNotifier,
    this.isMosaic = false,
    this.selectable = true,
    this.highlightable = true,
    this.heroTagger,
    this.heroPlaceholderBuilder,
    this.imageDecorator,
  });

  @override
  Widget build(BuildContext context) {
    final double thumbnailHeight = tileExtent;
    final double thumbnailWidth;
    if (isMosaic) {
      thumbnailWidth =
          thumbnailHeight *
          entry.displayAspectRatio.clamp(
            MosaicSectionLayoutBuilder.minThumbnailAspectRatio,
            MosaicSectionLayoutBuilder.maxThumbnailAspectRatio,
          );
    } else {
      thumbnailWidth = tileExtent;
    }

    Widget child = ThumbnailImage(
      entry: entry,
      extent: tileExtent,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      isMosaic: isMosaic,
      cancellableNotifier: cancellableNotifier,
      heroTag: heroTagger?.call(),
      heroPlaceholderBuilder: heroPlaceholderBuilder,
    );

    child = Stack(
      fit: StackFit.passthrough,
      children: [
        imageDecorator?.call(context, child) ?? child,
        ThumbnailEntryOverlay(entry: entry),
        if (selectable) ...[
          GridItemSelectionOverlay<FmvEntry>(
            item: entry,
            padding: const EdgeInsets.all(2),
          ),
          ThumbnailZoomOverlay(
            onZoom: () => OpenViewerNotification(entry).dispatch(context),
          ),
        ],
        if (highlightable) ThumbnailHighlightOverlay(entry: entry),
      ],
    );

    return Container(
      // `decoration` with sub logical pixel width yields scintillating borders
      // so we use `foregroundDecoration` instead
      foregroundDecoration: BoxDecoration(
        border: Border.fromBorderSide(
          BorderSide(
            color: borderColor(context),
            width: borderWidth(context),
          ),
        ),
      ),
      width: thumbnailWidth,
      height: thumbnailHeight,
      child: child,
    );
  }
}
