import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraLengthUnitView on LengthUnit {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      LengthUnit.px => l10n.lengthUnitPixel,
      LengthUnit.percent => l10n.lengthUnitPercent,
    };
  }
}
