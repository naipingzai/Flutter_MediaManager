import 'dart:math';

import 'package:flutter/widgets.dart';

import 'animation_configurator.dart';

/// An enum representing a flip axis.
enum FlipAxis {
  /// The x axis (vertical flip)
  x,

  /// The y axis (horizontal flip)
  y,
}

/// An animation that flips its child either vertically or horizontally.
class FlipAnimation extends StatefulWidget {
  /// The duration of the child animation.
  final Duration? duration;

  /// The delay between the beginning of two children's animations.
  final Duration? delay;

  /// The curve of the child animation. Defaults to [Curves.ease].
  final Curve curve;

  /// The [FlipAxis] in which the child widget will be flipped.
  final FlipAxis flipAxis;

  /// The child Widget to animate.
  final Widget child;

  /// Creates a flip animation that flips its child.
  ///
  /// Default value for [flipAxis] is [FlipAxis.x].
  ///
  /// The [child] argument must not be null.
  const FlipAnimation({super.key, this.duration, this.delay, this.curve = Curves.ease, this.flipAxis = FlipAxis.x, required this.child});

  @override
  State<FlipAnimation> createState() => _FlipAnimationState();
}

class _FlipAnimationState extends State<FlipAnimation> {
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
    return AnimationConfigurator(duration: widget.duration, delay: widget.delay, animatedChildBuilder: _flipAnimation);
  }

  Widget _flipAnimation(Animation<double> animation) {
    _setCurvedAnimation(
      CurvedAnimation(
        parent: animation,
        curve: Interval(0.0, 1.0, curve: widget.curve),
      ),
    );
    final _flipAnimation = Tween<double>(begin: 0, end: 1).animate(_curvedAnimation!);

    Matrix4 _computeTransformationMatrix() {
      var radians = (1 - _flipAnimation.value) * pi / 2;

      switch (widget.flipAxis) {
        case FlipAxis.y:
          return Matrix4.rotationY(radians);
        case FlipAxis.x:
          return Matrix4.rotationX(radians);
      }
    }

    return Transform(transform: _computeTransformationMatrix(), alignment: Alignment.center, child: widget.child);
  }
}
