import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/aves_app.dart';
import 'package:flutter/material.dart';

class LinkChip extends StatelessWidget {
  final Widget? leading;
  final String text;
  final String? urlString;
  final Color? color;
  final TextStyle? textStyle;
  final VoidCallback? onTap;

  static const borderRadius = BorderRadius.all(Radius.circular(8));

  const LinkChip({
    super.key,
    this.leading,
    required this.text,
    this.urlString,
    this.color,
    this.textStyle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: (textStyle ?? const TextStyle()).copyWith(color: color),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap ?? () => FmvApp.launchUrl(urlString),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: .min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (context) => Icon(
                  AIcons.openOutside,
                  size: DefaultTextStyle.of(context).style.fontSize,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
