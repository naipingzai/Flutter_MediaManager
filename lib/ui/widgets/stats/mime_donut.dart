import 'package:flutter_media_view/function/function_filters_mime.dart';
import 'package:flutter_media_view/function/function_settings.dart';
import 'package:flutter_media_view/ui/theme/colors.dart';
import 'package:flutter_media_view/function/function_mime_utils.dart';
import 'package:flutter_media_view/ui/widgets/common/identity/aves_donut.dart';
import 'package:flutter_media_view/ui/widgets/common/identity/aves_filter_chip.dart';
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
    final itemCountFormatter = settings.avesLocale.decimalNumberFormat();

    String formatKey(d) => MimeUtils.displayType(d.key);
    return AvesDonut(
      title: Icon(icon),
      byTypes: byMimeTypes,
      animationDuration: animationDuration,
      formatKey: formatKey,
      formatValue: itemCountFormatter.format,
      colorize: (context, d) {
        final colors = context.read<AvesColorsData>();
        return colors.fromString(formatKey(d));
      },
      onTap: (d) => onFilterSelection(MimeFilter(d.key)),
    );
  }
}
