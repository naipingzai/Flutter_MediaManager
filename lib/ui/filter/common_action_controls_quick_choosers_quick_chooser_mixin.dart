import 'dart:math';

import 'package:flutter_media_view/function/filters/filters.dart';
import 'package:flutter_media_view/function/settings/modules_history.dart';
import 'package:flutter_media_view/ui/filter/common_identity_fmv_filter_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

mixin FilterQuickChooserMixin<T> {
  List<T> get options;

  static const int maxTotalOptionCount = HistorySettings.recentFilterHistoryMax;
  static const double _chipPadding = FmvFilterChip.defaultPadding;
  static const bool _chipAllowGenericIcon = false;

  CollectionFilter buildFilter(BuildContext context, T option);

  Widget itemBuilder(BuildContext context, T option) {
    return FmvFilterChip(
      filter: buildFilter(context, option),
      allowGenericIcon: _chipAllowGenericIcon,
      padding: _chipPadding,
      maxWidth: double.infinity,
    );
  }

  double computeItemHeight(BuildContext context) => FmvFilterChip.minChipHeight;

  double? computeLargestItemWidth(BuildContext context) {
    if (options.isEmpty) return null;

    final textStyle = DefaultTextStyle.of(context).style.copyWith(
      fontSize: FmvFilterChip.fontSize,
    );
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final iconSize = textScaler.scale(FmvFilterChip.iconSize);

    return options
        .map((option) {
          final filter = buildFilter(context, option);
          final icon = filter.iconBuilder(context, iconSize, allowGenericIcon: _chipAllowGenericIcon);
          final label = filter.getLabel(context);

          final paragraph = RenderParagraph(
            TextSpan(text: label, style: textStyle),
            textDirection: textDirection,
            textScaler: textScaler,
          )..layout(const BoxConstraints(), parentUsesSize: true);
          final labelWidth = paragraph.getMaxIntrinsicWidth(double.infinity);
          paragraph.dispose();

          double chipWidth = labelWidth + _chipPadding * 4;
          if (icon != null) {
            chipWidth += iconSize + _chipPadding;
          }
          return max(FmvFilterChip.minChipWidth, chipWidth);
        })
        .reduce(max);
  }
}
