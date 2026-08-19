import 'package:flutter_media_view/function/filters/mime.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/theme/colors.dart';
import 'package:flutter_media_view/function/utils/mime_utils.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_fmv_donut.dart';
import 'package:flutter_media_view/ui/filter/common_identity_fmv_filter_chip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MimeDonut extends StatelessWidget {
  final IconData icon;
  final Map<String, int> byMimeTypes;
  final Duration animationDuration;
  final AFilterCallback onFilterSelection;

  const MimeDonut({
    super.key,
    required this.icon,
    required this.byMimeTypes,
    required this.animationDuration,
    required this.onFilterSelection,
  });

  @override
  Widget build(BuildContext context) {
    final itemCountFormatter = settings.fmvLocale.decimalNumberFormat();

    String formatKey(d) => MimeUtils.displayType(d.key);
    return FmvDonut(
      title: Icon(icon),
      byTypes: byMimeTypes,
      animationDuration: animationDuration,
      formatKey: formatKey,
      formatValue: itemCountFormatter.format,
      colorize: (context, d) {
        final colors = context.read<FmvColorsData>();
        return colors.fromString(formatKey(d));
      },
      onTap: (d) => onFilterSelection(MimeFilter(d.key)),
    );
  }
}
