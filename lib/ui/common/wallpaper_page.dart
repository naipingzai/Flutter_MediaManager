import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_multipage.dart';
import 'package:flutter_media_view/function/entry/extensions_props.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/common/fmv_app.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_insets.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/common_extensions_theme.dart';
import 'package:flutter_media_view/ui/viewer/action_video_action_delegate.dart';
import 'package:flutter_media_view/ui/viewer/controls_controller.dart';
import 'package:flutter_media_view/ui/viewer/controls_notifications.dart';
import 'package:flutter_media_view/ui/viewer/entry_horizontal_pager.dart';
import 'package:flutter_media_view/ui/viewer/multipage_conductor.dart';
import 'package:flutter_media_view/ui/viewer/overlay_bottom.dart';
import 'package:flutter_media_view/ui/viewer/overlay_bottom_video.dart';
import 'package:flutter_media_view/ui/viewer/page_entry_builder.dart';
import 'package:flutter_media_view/ui/viewer/viewer_providers.dart';
import 'package:flutter_media_view/ui/viewer/video_conductor.dart';
import 'package:flutter_media_view/ui/viewer/visual_controller_mixin.dart';
import 'package:fmv_magnifier/flutter_media_view_magnifier.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:fmv_video/flutter_media_view_video.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WallpaperPage extends StatelessWidget {
  static const routeName = '/set_wallpaper';

  final FmvEntry? entry;

  const WallpaperPage({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    return FmvScaffold(
      body: entry != null
          ? MultiProvider(
              providers: [
                ViewStateConductorProvider(),
                VideoConductorProvider(),
                MultiPageConductorProvider(),
              ],
              child: EntryEditor(
                entry: entry!,
              ),
            )
          : const SizedBox(),
      backgroundColor: Theme.of(context).isDark ? Colors.black : Colors.white,
      resizeToAvoidBottomInset: false,
    );
  }
}

class EntryEditor extends StatefulWidget {
  final FmvEntry entry;

  const EntryEditor({
    super.key,
    required this.entry,
  });

  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> with EntryViewControllerMixin, SingleTickerProviderStateMixin {
  final ValueNotifier<bool> _overlayVisible = ValueNotifier(true);
  late AnimationController _overlayAnimationController;
  late CurvedAnimation _overlayVideoControlScale;
  EdgeInsets? _frozenViewInsets, _frozenViewPadding;
  late VideoActionDelegate _videoActionDelegate;
  late final ViewerController _viewerController;

  @override
  bool get isViewingImage => true;

  @override
  final ValueNotifier<FmvEntry?> entryNotifier = ValueNotifier(null);

  FmvEntry get entry => widget.entry;

  @override
  void initState() {
    super.initState();
    if (settings.maxBrightness == MaxBrightness.viewerOnly) {
      FmvApp.screenBrightness?.setApplicationScreenBrightness(1);
    }
    if (settings.keepScreenOn == KeepScreenOn.viewerOnly) {
      windowService.keepScreenOn(true);
    }

    entryNotifier.value = entry;
    _overlayAnimationController = AnimationController(
      duration: context.read<DurationsData>().viewerOverlayAnimation,
      vsync: this,
    );
    _overlayVideoControlScale = CurvedAnimation(
      parent: _overlayAnimationController,
      // no bounce at the bottom, to avoid video controller displacement
      curve: Curves.easeOutQuad,
    );
    _overlayVisible.addListener(_onOverlayVisibleChanged);
    _videoActionDelegate = VideoActionDelegate(
      collection: null,
    );

    _viewerController = ViewerController(
      initialScale: const ScaleLevel(ref: ScaleReference.covered),
    );
    initEntryControllers(entry);
    _onOverlayVisibleChanged();
  }

  @override
  void dispose() {
    cleanEntryControllers(entry);
    _overlayVisible.dispose();
    _overlayVideoControlScale.dispose();
    _overlayAnimationController.dispose();
    _videoActionDelegate.dispose();
    _viewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      onNotification: _handleNotification,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              SingleEntryScroller(
                entry: entry,
                viewerController: _viewerController,
              ),
              Positioned(
                bottom: 0,
                child: _buildBottomOverlay(viewSize),
              ),
              const TopGestureAreaProtector(),
              const SideGestureAreaProtector(),
              const BottomGestureAreaProtector(),
            ],
          );
        },
      ),
    );
  }

  bool _handleNotification(Notification notification) {
    if (notification is ToggleOverlayNotification) {
      _overlayVisible.value = notification.visible ?? !_overlayVisible.value;
    } else if (notification is VideoActionNotification) {
      _onVideoAction(
        context: context,
        entry: notification.entry,
        controller: notification.controller,
        action: notification.action,
      );
    }
    return true;
  }

  Widget _buildBottomOverlay(Size viewSize) {
    final mainEntry = entry;
    final multiPageController = mainEntry.isMultiPage ? context.read<MultiPageConductor>().getController(mainEntry) : null;

    Widget? _buildExtraBottomOverlay({FmvEntry? pageEntry}) {
      final targetEntry = pageEntry ?? mainEntry;
      Widget? child;
      // a 360 video is both a video and a panorama but only the video controls are displayed
      if (targetEntry.isPureVideo) {
        child = Selector<VideoConductor, FmvVideoController?>(
          selector: (context, vc) => vc.getController(targetEntry),
          builder: (context, videoController, child) => VideoControlOverlay(
            entry: targetEntry,
            controller: videoController,
            scale: _overlayVideoControlScale,
            onActionSelected: (action) => _onVideoAction(
              context: context,
              entry: targetEntry,
              controller: videoController,
              action: action,
            ),
          ),
        );
      }
      return child != null
          ? ExtraBottomOverlay(
              viewInsets: _frozenViewInsets,
              viewPadding: _frozenViewPadding,
              child: child,
            )
          : null;
    }

    final extraBottomOverlay = mainEntry.isMultiPage
        ? PageEntryBuilder(
            multiPageController: multiPageController,
            builder: (pageEntry) => _buildExtraBottomOverlay(pageEntry: pageEntry) ?? const SizedBox(),
          )
        : _buildExtraBottomOverlay();

    final child = TooltipTheme(
      data: TooltipTheme.of(context).copyWith(
        preferBelow: false,
      ),
      child: Column(
        children: [
          ?extraBottomOverlay,
          ViewerBottomOverlay(
            entries: [widget.entry],
            index: 0,
            collection: null,
            animationController: _overlayAnimationController,
            availableSize: viewSize,
            viewInsets: _frozenViewInsets,
            viewPadding: _frozenViewPadding,
            multiPageController: multiPageController,
          ),
        ],
      ),
    );

    return ValueListenableBuilder<double>(
      valueListenable: _overlayAnimationController,
      builder: (context, animation, child) {
        return Visibility(
          visible: !_overlayAnimationController.isDismissed,
          child: child!,
        );
      },
      child: child,
    );
  }

  void _onVideoAction({
    required BuildContext context,
    required FmvEntry entry,
    required FmvVideoController? controller,
    required EntryAction action,
  }) {
    if (controller != null) {
      _videoActionDelegate.onActionSelected(context, entry, controller, action);
    }
  }

  // overlay

  Future<void> _onOverlayVisibleChanged({bool animate = true}) async {
    if (_overlayVisible.value) {
      await FmvApp.showSystemUI(true);
      if (animate) {
        await _overlayAnimationController.forward();
      } else {
        _overlayAnimationController.value = _overlayAnimationController.upperBound;
      }
    } else {
      final mediaQuery = context.read<MediaQueryData>();
      setState(() {
        _frozenViewInsets = mediaQuery.viewInsets;
        _frozenViewPadding = mediaQuery.viewPadding;
      });
      await FmvApp.showSystemUI(false);
      if (animate) {
        await _overlayAnimationController.reverse();
      } else {
        _overlayAnimationController.reset();
      }
      setState(() {
        _frozenViewInsets = null;
        _frozenViewPadding = null;
      });
    }
  }
}
