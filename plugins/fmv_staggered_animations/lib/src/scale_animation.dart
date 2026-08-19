import 'package:flutter/widgets.dart';

import 'animation_configurator.dart';

/// An animation that scales its child.
class ScaleAnimation extends StatefulWidget {
  /// The duration of the child animation.
  final Duration? duration;

  /// The delay between the beginning of two children's animations.
  final Duration? delay;

  /// The curve of the child animation. Defaults to [Curves.ease].
  final Curve curve;

  /// Scaling factor to apply at the start of the animation.
  final double scale;

  /// The child Widget to animate.
  final Widget child;

  /// Creates a scale animation that scales its child for its center.
  ///
  /// Default value for [scale] is 0.0.
  ///
  /// The [child] argument must not be null.
  const ScaleAnimation({super.key, this.duration, this.delay, this.curve = Curves.ease, this.scale = 0.0, required this.child}) : assert(scale >= 0.0);

  @override
  State<ScaleAnimation> createState() => _ScaleAnimationState();
}

class _ScaleAnimationState extends State<ScaleAnimation> {
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
    return AnimationConfigurator(duration: widget.duration, delay: widget.delay, animatedChildBuilder: _landingAnimation);
  }

  Widget _landingAnimation(Animation<double> animation) {
    _setCurvedAnimation(
      CurvedAnimation(
        parent: animation,
        curve: Interval(0.0, 1.0, curve: widget.curve),
      ),
    );
    final _landingAnimation = Tween<double>(begin: widget.scale, end: 1.0).animate(_curvedAnimation!);

    return Transform.scale(scale: _landingAnimation.value, child: widget.child);
  }
}
