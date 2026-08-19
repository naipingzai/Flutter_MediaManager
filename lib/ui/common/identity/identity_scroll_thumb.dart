import 'package:flutter_media_view/ui/common/basic/basic_draggable_scrollbar_arrow_clipper.dart';
import 'package:flutter_media_view/ui/common/basic/basic_draggable_scrollbar.dart';
import 'package:flutter/material.dart';

class FmvScrollThumb {
  static const EdgeInsetsGeometry _margin = EdgeInsetsDirectional.only(end: 1);
  static const EdgeInsets _padding = .all(2);
  static const double _width = 20;
  static final double _thumbWidth = _width + _padding.horizontal + _margin.horizontal;

  static const double thumbHeight = 48;
  static final thumbSize = Size(_thumbWidth, thumbHeight);

  // height and background color do not change
  // so we do not rely on the builder props
  static ScrollThumbBuilder builder({
    required double height,
    required Color backgroundColor,
  }) {
    final scrollThumb = Container(
      decoration: const BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      height: height,
      margin: _margin,
      padding: _padding,
      child: ClipPath(
        clipper: ArrowClipper(),
        child: Container(
          width: _width,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
    return (backgroundColor, thumbAnimation, labelAnimation, height, {labelText}) {
      return DraggableScrollbar.buildScrollThumbAndLabel(
        scrollThumb: scrollThumb,
        backgroundColor: backgroundColor,
        thumbAnimation: thumbAnimation,
        labelAnimation: labelAnimation,
        labelText: labelText,
      );
    };
  }
}
