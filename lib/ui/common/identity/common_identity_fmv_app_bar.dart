import 'dart:async';
import 'dart:math';

import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/theme/themes.dart';
import 'package:flutter_media_view/ui/common/fmv_app.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_font_size_icon_theme.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_gestures_ink_well.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_insets.dart';
import 'package:flutter_media_view/ui/common/common_fx_blurred.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class FmvAppBar extends StatelessWidget {
  final double contentHeight;
  final bool pinned;
  final Widget? leading;
  final Widget title;
  final List<Widget> Function(BuildContext context, double maxWidth) actions;
  final Widget? bottom;
  final Object? transitionKey;

  static const leadingHeroTag = 'appbar-leading';
  static const titleHeroTag = 'appbar-title';
  static const double _titleMinWidth = 96;

  const FmvAppBar({
    super.key,
    required this.contentHeight,
    required this.pinned,
    required this.leading,
    required this.title,
    required this.actions,
    this.bottom,
    this.transitionKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final colorScheme = theme.colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final useTvLayout = settings.useTvLayout;

    Widget? _leading = leading;
    if (_leading != null) {
      _leading = FontSizeIconTheme(
        child: _leading,
      );
    }

    Widget _title = FontSizeIconTheme(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            key: ValueKey(transitionKey),
            children: [
              Expanded(child: title),
              ...(actions(context, max(0, constraints.maxWidth - _titleMinWidth))),
            ],
          );
        },
      ),
    );

    final animate = context.select<Settings, bool>((v) => v.animate);
    if (animate) {
      _title = Hero(
        tag: titleHeroTag,
        flightShuttleBuilder: _flightShuttleBuilder,
        transitionOnUserGestures: true,
        child: AnimatedSwitcher(
          duration: context.read<DurationsData>().iconAnimation,
          child: _title,
        ),
      );

      if (_leading != null) {
        _leading = Hero(
          tag: leadingHeroTag,
          flightShuttleBuilder: _flightShuttleBuilder,
          transitionOnUserGestures: true,
          child: _leading,
        );
      }
    }

    return SliverPersistentHeader(
      floating: !useTvLayout,
      pinned: pinned,
      delegate: _SliverAppBarDelegate(
        height: MediaQuery.paddingOf(context).top + appBarHeightForContentHeight(contentHeight),
        child: DirectionalSafeArea(
          start: !useTvLayout,
          bottom: false,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: appBarTheme.systemOverlayStyle!,
            child: FmvFloatingBar(
              builder: (context, backgroundColor, child) => Material(
                color: backgroundColor,
                child: AInkResponse(
                  // absorb taps while providing visual feedback
                  onTap: () {},
                  onLongPress: () {},
                  containedInkWell: true,
                  highlightShape: BoxShape.rectangle,
                  longPressTimeout: settings.longPressTimeout,
                  child: child,
                ),
              ),
              child: Theme(
                data: theme.copyWith(
                  colorScheme: colorScheme.copyWith(
                    onSurfaceVariant: colorScheme.onSurface,
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: textScaler.scale(kToolbarHeight),
                      child: Row(
                        children: [
                          _leading != null
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: _leading,
                                )
                              : const SizedBox(width: 16),
                          Expanded(
                            child: DefaultTextStyle(
                              style: appBarTheme.titleTextStyle!,
                              child: _title,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ?bottom,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _flightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final pushing = flightDirection == HeroFlightDirection.push;
    Widget popBuilder(context, child) => Opacity(opacity: 1 - animation.value, child: child);
    Widget pushBuilder(context, child) => Opacity(opacity: animation.value, child: child);
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: DefaultTextStyle.of(toHeroContext).style,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: pushing ? popBuilder : pushBuilder,
              child: fromHeroContext.widget,
            ),
            AnimatedBuilder(
              animation: animation,
              builder: pushing ? pushBuilder : popBuilder,
              child: toHeroContext.widget,
            ),
          ],
        ),
      ),
    );
  }

  static double appBarHeightForContentHeight(double contentHeight) => FmvFloatingBar.margin.vertical + contentHeight;
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _SliverAppBarDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) => true;
}

class FmvFloatingBar extends StatefulWidget {
  final Widget Function(BuildContext context, Color backgroundColor, Widget? child) builder;
  final Widget? child;

  static const margin = EdgeInsets.all(8);
  static const borderRadius = BorderRadius.all(Radius.circular(8));

  const FmvFloatingBar({
    super.key,
    required this.builder,
    this.child,
  });

  @override
  State<FmvFloatingBar> createState() => _FmvFloatingBarState();
}

class _FmvFloatingBarState extends State<FmvFloatingBar> with RouteAware {
  // prevent expensive blurring when the current page is hidden
  final ValueNotifier<bool> _isBlurAllowedNotifier = ValueNotifier(true);
  Timer? _blurBlockTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      FmvApp.pageRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    FmvApp.pageRouteObserver.unsubscribe(this);
    _isBlurAllowedNotifier.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // post to prevent single frame flash during hero
    _blurBlockTimer?.cancel();
    _blurBlockTimer = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _isBlurAllowedNotifier.value = true;
    });
  }

  @override
  void didPushNext() {
    // delay blur disabling, otherwise visual artifacts appear during page transition with Impeller
    _blurBlockTimer?.cancel();
    _blurBlockTimer = Timer(ADurations.pageTransitionLoose, () {
      if (mounted) {
        _isBlurAllowedNotifier.value = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.appBarTheme.backgroundColor ?? Themes.firstLayerColor(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _isBlurAllowedNotifier,
      builder: (context, isBlurAllowed, child) {
        final blurred = isBlurAllowed && context.select<Settings, bool>((v) => v.enableBlurEffect);
        return Container(
          foregroundDecoration: BoxDecoration(
            border: Border.all(
              color: theme.dividerColor,
            ),
            borderRadius: FmvFloatingBar.borderRadius,
          ),
          margin: FmvFloatingBar.margin,
          child: BlurredRRect(
            enabled: blurred,
            borderRadius: FmvFloatingBar.borderRadius,
            child: widget.builder(
              context,
              blurred ? backgroundColor.withValues(alpha: .85) : backgroundColor,
              widget.child,
            ),
          ),
        );
      },
    );
  }
}
