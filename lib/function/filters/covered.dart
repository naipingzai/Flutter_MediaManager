import 'package:fmv/function/model/covers.dart';
import 'package:fmv/function/filters/filters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

@immutable
mixin CoveredFilter on CollectionFilter {
  @override
  Future<Color> color(BuildContext context) {
    final customColor = covers.of(this)?.color;
    if (customColor != null) {
      return SynchronousFuture(customColor);
    }
    return super.color(context);
  }
}
