// Copyright 2018 the Charts project authors. Please see the AUTHORS file
// for details.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:ui' show TextAlign, TextDirection;
import 'package:fmv_charts_common/community_charts_common.dart' as common
    show
        MaxWidthStrategy,
        TextElement,
        TextDirection,
        TextMeasurement,
        TextStyle;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart'
    show Color, TextBaseline, TextPainter, TextScaler, TextSpan, TextStyle, FontWeight;
import 'package:leak_tracker/leak_tracker.dart';

/// Flutter implementation for text measurement and painter.
class TextElement implements common.TextElement {
  static const ellipsis = '\u{2026}';

  @override
  final String text;

  final TextScaler? textScaler;

  var _painterReady = false;
  common.TextStyle? _textStyle;
  common.TextDirection _textDirection = common.TextDirection.ltr;

  int? _maxWidth;
  common.MaxWidthStrategy? _maxWidthStrategy;

  TextPainter? _textPainter;

  late common.TextMeasurement _measurement;

  double? _opacity;

  TextElement(this.text, {common.TextStyle? style, this.textScaler})
      : _textStyle = style {
    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectCreated(
        library: 'charts_flutter',
        className: '$TextElement',
        object: this,
      );
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    // the same `textElement` may be shared for update efficiency,
    // (e.g. `common` library `Axis` animated ticks and provided ticks)
    // so we prevent disposing the underlying `TextPainter` more than once
    if (_disposed) return;
    _disposed = true;

    if (kFlutterMemoryAllocationsEnabled) {
      LeakTracking.dispatchObjectDisposed(object: this);
    }
    _textPainter?.dispose();
  }

  @override
  common.TextStyle? get textStyle => _textStyle;

  @override
  set textStyle(common.TextStyle? value) {
    if (_textStyle == value) {
      return;
    }
    _textStyle = value;
    _painterReady = false;
  }

  @override
  set textDirection(common.TextDirection direction) {
    if (_textDirection == direction) {
      return;
    }
    _textDirection = direction;
    _painterReady = false;
  }

  @override
  common.TextDirection get textDirection => _textDirection;

  @override
  int? get maxWidth => _maxWidth;

  @override
  set maxWidth(int? value) {
    if (_maxWidth == value) {
      return;
    }
    _maxWidth = value;
    _painterReady = false;
  }

  @override
  common.MaxWidthStrategy? get maxWidthStrategy => _maxWidthStrategy;

  @override
  set maxWidthStrategy(common.MaxWidthStrategy? maxWidthStrategy) {
    if (_maxWidthStrategy == maxWidthStrategy) {
      return;
    }
    _maxWidthStrategy = maxWidthStrategy;
    _painterReady = false;
  }

  @override
  set opacity(double? opacity) {
    if (opacity != _opacity) {
      _painterReady = false;
      _opacity = opacity;
    }
  }

  @override
  common.TextMeasurement get measurement {
    if (!_painterReady) {
      _refreshPainter();
    }

    return _measurement;
  }

  /// The estimated distance between where we asked to draw the text (top, left)
  /// and where it visually started (top + verticalFontShift, left).
  ///
  /// 10% of reported font height seems to be about right.
  int get verticalFontShift {
    if (!_painterReady) {
      _refreshPainter();
    }

    return (textPainter.height * 0.1).ceil();
  }

  TextPainter get textPainter {
    if (!_painterReady) {
      _refreshPainter();
    }
    return _textPainter!;
  }

  /// Create text painter and measure based on current settings
  void _refreshPainter() {
    _opacity ??= 1.0;
    var color = (textStyle == null || textStyle!.color == null)
        ? null
        : new Color.fromARGB(
            (textStyle!.color!.a * _opacity!).round(),
            textStyle!.color!.r,
            textStyle!.color!.g,
            textStyle!.color!.b,
          );

    final newTextPainter = new TextPainter(
        text: new TextSpan(
            text: text,
            style: new TextStyle(
                color: color,
                fontSize: textStyle?.fontSize?.toDouble(),
                fontFamily: textStyle?.fontFamily,
                fontWeight: _effectiveFontWeight,
                height: textStyle?.lineHeight)))
      ..textDirection = TextDirection.ltr
      // TODO Flip once textAlign works
      ..textAlign = TextAlign.left
      // ..textAlign = _textDirection == common.TextDirection.rtl ?
      //     TextAlign.right : TextAlign.left
      ..ellipsis = maxWidthStrategy == common.MaxWidthStrategy.ellipsize
          ? ellipsis
          : null;

    if (textScaler != null) {
      newTextPainter.textScaler = textScaler!;
    }

    newTextPainter.layout(maxWidth: maxWidth?.toDouble() ?? double.infinity);

    final baseline =
        newTextPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    // Estimating the actual draw height to 70% of measures size.
    //
    // The font reports a size larger than the drawn size, which makes it
    // difficult to shift the text around to get it to visually line up
    // vertically with other components.
    _measurement = new common.TextMeasurement(
        horizontalSliceWidth: newTextPainter.width,
        verticalSliceWidth: newTextPainter.height * 0.70,
        baseline: baseline);

    _textPainter?.dispose();
    _textPainter = newTextPainter;
    _painterReady = true;
  }

  FontWeight? get _effectiveFontWeight {
    final name = textStyle?.fontWeight?.toLowerCase();
    if (name == null) return null;
    final value = int.tryParse(name);
    if (value == null) {
      if (name == 'normal') return FontWeight.normal;
      if (name == 'bold') return FontWeight.bold;
    } else {
      return FontWeight.values[value.clamp(100, 900) ~/ 100 - 1];
    }
    return null;
  }
}
