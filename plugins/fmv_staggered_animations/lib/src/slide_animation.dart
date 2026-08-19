import 'package:flutter/widgets.dart';

import 'animation_configurator.dart';

/// An animation that slides its child.
class SlideAnimation extends StatefulWidget {
  /// The duration of the child animation.
  final Duration? duration;

  /// The delay between the beginning of two children's animations.
  final Duration? delay;

  /// The curve of the child animation. Defaults to [Curves.ease].
  final Curve curve;

  /// The vertical offset to apply at the start of the animation (can be negative).
  final double verticalOffset;

  /// The horizontal offset to apply at the start of the animation (can be negative).
  final double horizontalOffset;

  /// The child Widget to animate.
  final Widget child;

  /// Creates a slide animation that slides its child from the given
  /// [verticalOffset] and [horizontalOffset] to its final position.
  ///
  /// A default value of 50.0 is applied to [verticalOffset] if
  /// [verticalOffset] and [horizontalOffset] are both undefined or null.
  ///
  /// The [child] argument must not be null.
  const SlideAnimation({super.key, this.duration, this.delay, this.curve = Curves.ease, double? verticalOffset, double? horizontalOffset, required this.child}) : verticalOffset = (verticalOffset == null && horizontalOffset == null) ? 50.0 : (verticalOffset ?? 0.0), horizontalOffset = horizontalOffset ?? 0.0;

  @override
  State<SlideAnimation> createState() => _SlideAnimationState();
}

class _SlideAnimationState extends State<SlideAnimation> {
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
    return AnimationConfigurator(duration: widget.duration, delay: widget.delay, animatedChildBuilder: _slideAnimation);
  }

  Widget _slideAnimation(Animation<double> animation) {
    _setCurvedAnimation(
      CurvedAnimation(
        parent: animation,
        curve: Interval(0.0, 1.0, curve: widget.curve),
      ),
    );

    Animation<double> offsetAnimation(double offset, Animation<double> animation) {
      return Tween<double>(begin: offset, end: 0.0).animate(_curvedAnimation!);
    }

    final dx = widget.horizontalOffset == 0.0 ? 0.0 : offsetAnimation(widget.horizontalOffset, animation).value;
    final dy = widget.verticalOffset == 0.0 ? 0.0 : offsetAnimation(widget.verticalOffset, animation).value;
    return Transform.translate(offset: Offset(dx, dy), child: widget.child);
  }
}
