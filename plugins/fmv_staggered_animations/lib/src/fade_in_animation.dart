import 'package:flutter/widgets.dart';

import 'animation_configurator.dart';

/// An animation that fades its child.
class FadeInAnimation extends StatefulWidget {
  /// The duration of the child animation.
  final Duration? duration;

  /// The delay between the beginning of two children's animations.
  final Duration? delay;

  /// The curve of the child animation. Defaults to [Curves.ease].
  final Curve curve;

  /// The child Widget to animate.
  final Widget child;

  /// Creates a fade animation that fades its child.
  ///
  /// The [child] argument must not be null.
  const FadeInAnimation({super.key, this.duration, this.delay, this.curve = Curves.ease, required this.child});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation> {
  CurvedAnimation? _curvedAnimation;

  @override
  void dispose() {
    _setCurvedAnimation(null);
    super.dispose();
  }

  void _setCurvedAnimation(CurvedAnimation? animation) {
    _curvedAnimation?.dispose();
    _curvedAnimation = animation;
  }

  @override
  Widget build(BuildContext context) {
    return AnimationConfigurator(duration: widget.duration, delay: widget.delay, animatedChildBuilder: _fadeInAnimation);
  }

  Widget _fadeInAnimation(Animation<double> animation) {
    _setCurvedAnimation(
      CurvedAnimation(
        parent: animation,
        curve: Interval(0.0, 1.0, curve: widget.curve),
      ),
    );
    final _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_curvedAnimation!);

    return Opacity(opacity: _opacityAnimation.value, child: widget.child);
  }
}
