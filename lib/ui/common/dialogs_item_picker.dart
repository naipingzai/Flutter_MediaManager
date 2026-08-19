import 'dart:math';

import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/extensions_theme.dart';
import 'package:flutter_media_view/ui/common/fx_borders.dart';
import 'package:flutter_media_view/ui/common/thumbnails/common_thumbnail_image.dart';
import 'package:flutter/material.dart';

class ItemPicker extends StatelessWidget {
  final double extent;
  final FmvEntry entry;
  final GestureTapCallback? onTap;

  const ItemPicker({
    super.key,
    required this.extent,
    required this.entry,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageBorderRadius = BorderRadius.all(Radius.circular(extent * .25));
    final actionBoxDimension = min(40.0, extent * .4);
    final actionBoxBorderRadius = BorderRadiusDirectional.only(topStart: Radius.circular(actionBoxDimension * .6));
    return Tooltip(
      message: context.l10n.changeTooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: FmvBorder.border(context),
            borderRadius: imageBorderRadius,
          ),
          child: ClipRRect(
            borderRadius: imageBorderRadius,
            child: SizedBox(
              width: extent,
              height: extent,
              child: Stack(
                children: [
                  ThumbnailImage(
                    entry: entry,
                    extent: extent,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  ),
                  PositionedDirectional(
                    end: -1,
                    bottom: -1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).isDark ? const Color(0xAA000000) : const Color(0xCCFFFFFF),
                        border: FmvBorder.border(context),
                        borderRadius: actionBoxBorderRadius,
                      ),
                      width: actionBoxDimension,
                      height: actionBoxDimension,
                      child: Icon(
                        AIcons.edit,
                        size: actionBoxDimension * .6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
