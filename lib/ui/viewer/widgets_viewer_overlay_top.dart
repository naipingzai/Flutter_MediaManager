import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_multipage.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/viewer/view_state.dart';
import 'package:flutter_media_view/ui/theme/themes.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/common_fx_blurred.dart';
import 'package:flutter_media_view/ui/common/common_fx_borders.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_multipage_conductor.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_overlay_top_details.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_overlay_top_histogram.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_overlay_top_minimap.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_page_entry_builder.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_view_conductor.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_view_controller.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ViewerTopOverlay extends StatelessWidget {
  final List<FmvEntry> entries;
  final int index;
  final FmvEntry mainEntry;
  final Animation<double> scale;
  final bool hasCollection;
  final ValueNotifier<bool> expandedNotifier;
  final Size availableSize;
  final EdgeInsets? viewInsets, viewPadding;

  static const Color componentBorderColor = Colors.white30;
  static const double componentDimension = 96;

  const ViewerTopOverlay({
    super.key,
    required this.entries,
    required this.index,
    required this.mainEntry,
    required this.scale,
    required this.hasCollection,
    required this.expandedNotifier,
    required this.availableSize,
    required this.viewInsets,
    required this.viewPadding,
  });

  @override
  Widget build(BuildContext context) {
    final multiPageController = mainEntry.isMultiPage ? context.read<MultiPageConductor>().getController(mainEntry) : null;
    return PageEntryBuilder(
      multiPageController: multiPageController,
      builder: (pageEntry) {
        pageEntry ??= mainEntry;

        final showInfo = settings.showOverlayInfo;

        final viewStateConductor = context.read<ViewStateConductor>();
        final viewStateNotifier = viewStateConductor.getOrCreateController(pageEntry).viewStateNotifier;

        final blurred = settings.enableBlurEffect;
        final viewInsetsPadding = (viewInsets ?? EdgeInsets.zero) + (viewPadding ?? EdgeInsets.zero);

        Widget _decorateCornerChild(Widget child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8) + const EdgeInsets.only(top: 8),
          child: FadeTransition(
            opacity: scale,
            child: child,
          ),
        );

        // 桌面平台无系统返回键，提供返回按钮
        final backButton = !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
            ? _decorateCornerChild(
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybeOf(context)?.maybePop(),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
            : null;
        final startCornerChildren = [
          if (backButton != null) backButton,
          if (settings.showOverlayZoomLevel)
            ZoomLevelIndicator(
              viewStateNotifier: viewStateNotifier,
            ),
          if (settings.showOverlayMinimap)
            Minimap(
              viewStateNotifier: viewStateNotifier,
            ),
        ];

        final endCornerChildren = [
          if (settings.overlayHistogramStyle != OverlayHistogramStyle.none)
            Selector<ViewStateConductor, ViewStateController>(
              selector: (context, vsc) => vsc.getOrCreateController(pageEntry!),
              builder: (context, viewStateController, child) {
                return ValueListenableBuilder<ImageProvider?>(
                  valueListenable: viewStateController.fullImageNotifier,
                  builder: (context, fullImage, child) {
                    if (fullImage == null || pageEntry == null) return const SizedBox();
                    return ImageHistogram(
                      viewStateController: viewStateController,
                      image: fullImage,
                    );
                  },
                );
              },
            ),
        ];

        return Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            if (showInfo)
              GestureDetector(
                onTap: () => expandedNotifier.value = !expandedNotifier.value,
                child: BlurredRect(
                  enabled: blurred,
                  child: Container(
                    color: Themes.overlayBackgroundColor(brightness: Theme.of(context).brightness, blurred: blurred),
                    child: SafeArea(
                      bottom: false,
                      minimum: EdgeInsets.only(
                        left: viewInsetsPadding.left,
                        top: viewInsetsPadding.top,
                        right: viewInsetsPadding.right,
                      ),
                      child: ViewerDetailOverlay(
                        index: index,
                        entries: entries,
                        hasCollection: hasCollection,
                        multiPageController: multiPageController,
                        expandedNotifier: expandedNotifier,
                        availableSize: availableSize,
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              top: !showInfo,
              minimum: EdgeInsets.only(
                left: viewInsetsPadding.left,
                right: viewInsetsPadding.right,
              ),
              child: Row(
                crossAxisAlignment: .start,
                children: [
                  if (startCornerChildren.isNotEmpty)
                    Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .start,
                      children: startCornerChildren.map(_decorateCornerChild).toList(),
                    ),
                  const Spacer(),
                  if (endCornerChildren.isNotEmpty)
                    Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .start,
                      children: endCornerChildren.map(_decorateCornerChild).toList(),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class ZoomLevelIndicator extends StatelessWidget {
  final ValueNotifier<ViewState> viewStateNotifier;

  const ZoomLevelIndicator({
    super.key,
    required this.viewStateNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final blurred = settings.enableBlurEffect;
    final border = FmvBorder.border(
      context,
      width: FmvBorder.curvedBorderWidth(context),
    );
    final borderRadius = BorderRadius.circular(4);
    final zoomScaleFactor = MediaQuery.devicePixelRatioOf(context) * 100;

    return IgnorePointer(
      child: BlurredRRect(
        enabled: blurred,
        borderRadius: borderRadius,
        child: Material(
          type: MaterialType.button,
          borderRadius: borderRadius,
          color: Themes.overlayBackgroundColor(brightness: Theme.of(context).brightness, blurred: blurred),
          child: ValueListenableBuilder<ViewState>(
            valueListenable: viewStateNotifier,
            builder: (context, viewState, child) {
              final viewportSize = viewState.viewportSize;
              final contentSize = viewState.contentSize;
              if ((viewportSize == null || viewportSize.isEmpty) || (contentSize == null || contentSize.isEmpty)) {
                return const SizedBox();
              }
              final zoom = ((viewState.scale ?? 0) * zoomScaleFactor).round();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                foregroundDecoration: BoxDecoration(
                  border: border,
                  borderRadius: borderRadius,
                ),
                child: Text(
                  '$zoom${context.l10n.lengthUnitPercent}',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    shadows: ViewerDetailOverlayContent.shadows(context),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
