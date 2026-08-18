import 'dart:math';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_images.dart';
import 'package:flutter_media_view/function/media/panorama.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/aves_app.dart';
import 'package:flutter_media_view/ui/common/common_basic_insets.dart';
import 'package:flutter_media_view/ui/common/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/common_extensions_media_query.dart';
import 'package:flutter_media_view/ui/common/common_identity_buttons_overlay_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:panorama/panorama.dart';
import 'package:provider/provider.dart';

class PanoramaPage extends StatefulWidget {
  static const routeName = '/viewer/panorama';

  final FmvEntry entry;
  final PanoramaInfo info;

  const PanoramaPage({
    super.key,
    required this.entry,
    required this.info,
  });

  @override
  State<PanoramaPage> createState() => _PanoramaPageState();
}

class _PanoramaPageState extends State<PanoramaPage> {
  final ValueNotifier<bool> _overlayVisible = ValueNotifier(true);
  final ValueNotifier<SensorControl> _sensorControl = ValueNotifier(.none);

  FmvEntry get entry => widget.entry;

  PanoramaInfo get info => widget.info;

  static const double _minZoom = .25;
  static const int _sensorOrientationMeanCount = 15;

  @override
  void initState() {
    super.initState();
    _overlayVisible.addListener(_onOverlayVisibleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initOverlay());
  }

  @override
  void dispose() {
    _overlayVisible.dispose();
    _sensorControl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) => _onLeave(),
      child: FmvScaffold(
        body: Stack(
          children: [
            ValueListenableBuilder<SensorControl>(
              valueListenable: _sensorControl,
              builder: (context, sensorControl, child) {
                void onTap(longitude, latitude, tilt) => _overlayVisible.value = !_overlayVisible.value;
                final imageChild = child as Image;

                if (info.hasCroppedArea) {
                  final croppedArea = info.croppedAreaRect!;
                  final fullSize = info.fullPanoSize!;
                  final longitude = ((croppedArea.left + croppedArea.width / 2) / fullSize.width - 1 / 2) * 360;
                  return Panorama(
                    longitude: longitude,
                    minZoom: _minZoom,
                    sensorControl: sensorControl,
                    sensorOrientationMeanCount: _sensorOrientationMeanCount,
                    croppedArea: croppedArea,
                    croppedFullWidth: fullSize.width,
                    croppedFullHeight: fullSize.height,
                    onTap: onTap,
                    child: imageChild,
                  );
                } else {
                  return Panorama(
                    minZoom: _minZoom,
                    sensorControl: sensorControl,
                    sensorOrientationMeanCount: _sensorOrientationMeanCount,
                    onTap: onTap,
                    child: imageChild,
                  );
                }
              },
              child: Image(
                image: entry.fullImage,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _buildOverlay(context),
            ),
            const TopGestureAreaProtector(),
            const SideGestureAreaProtector(),
            const BottomGestureAreaProtector(),
          ],
        ),
        resizeToAvoidBottomInset: false,
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    if (settings.useTvLayout) return const SizedBox();

    return TooltipTheme(
      data: TooltipTheme.of(context).copyWith(
        preferBelow: false,
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: _overlayVisible,
        builder: (context, overlayVisible, child) {
          return Visibility(
            visible: overlayVisible,
            child: Selector<MediaQueryData, double>(
              selector: (context, mq) => max(mq.effectiveBottomPadding, mq.systemGestureInsets.bottom),
              builder: (context, mqPaddingBottom, child) {
                return SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(8) + EdgeInsets.only(bottom: mqPaddingBottom),
                    child: child,
                  ),
                );
              },
              child: OverlayButton(
                child: ValueListenableBuilder<SensorControl>(
                  valueListenable: _sensorControl,
                  builder: (context, sensorControl, child) {
                    return IconButton(
                      icon: Icon(sensorControl == SensorControl.none ? AIcons.sensorControlEnabled : AIcons.sensorControlDisabled),
                      onPressed: _toggleSensor,
                      tooltip: sensorControl == SensorControl.none ? context.l10n.panoramaEnableSensorControl : context.l10n.panoramaDisableSensorControl,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _toggleSensor() {
    switch (_sensorControl.value) {
      case .none:
        _sensorControl.value = .absoluteOrientation;
      case .absoluteOrientation:
      case .orientation:
        _sensorControl.value = .none;
    }
  }

  Future<void> _onLeave() async {
    await FmvApp.showSystemUI(true);
  }

  // system UI

  // overlay

  Future<void> _initOverlay() async {
    // wait for MaterialPageRoute.transitionDuration
    // to show overlay after page animation is complete
    await Future.delayed(ModalRoute.of(context)!.transitionDuration * timeDilation);
    await _onOverlayVisibleChanged();
  }

  Future<void> _onOverlayVisibleChanged() async {
    if (_overlayVisible.value) {
      await FmvApp.showSystemUI(true);
    } else {
      await FmvApp.showSystemUI(false);
    }
  }
}
