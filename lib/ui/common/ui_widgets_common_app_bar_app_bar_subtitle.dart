import 'package:flutter_media_view/function/source/function_source_collection_source.dart';
import 'package:flutter_media_view/function/source/function_source_events.dart';
import 'package:flutter_media_view/ui/theme/ui_theme_durations.dart';
import 'package:flutter_media_view/ui/common/ui_view.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_theme.dart';
import 'package:flutter_media_view_model/flutter_media_view_model.dart';
import 'package:flutter/material.dart';

class SourceStateAwareAppBarTitle extends StatelessWidget {
  final Widget title;
  final CollectionSource source;

  const SourceStateAwareAppBarTitle({
    super.key,
    required this.title,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        title,
        ValueListenableBuilder<SourceState>(
          valueListenable: source.stateNotifier,
          builder: (context, sourceState, child) {
            return AnimatedSwitcher(
              duration: ADurations.appBarTitleAnimation,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  child: child,
                ),
              ),
              child: sourceState == SourceState.ready
                  ? const SizedBox()
                  : SourceStateSubtitle(
                      source: source,
                    ),
            );
          },
        ),
      ],
    );
  }
}

class SourceStateSubtitle extends StatelessWidget {
  final CollectionSource source;

  const SourceStateSubtitle({
    super.key,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final sourceState = source.state;
    final subtitle = sourceState.getName(context.l10n);
    if (subtitle == null) return const SizedBox();

    final theme = Theme.of(context);
    return DefaultTextStyle.merge(
      style: theme.textTheme.bodySmall!.copyWith(fontFeatures: const [FontFeature.disable('smcp')]),
      child: ValueListenableBuilder<ProgressEvent>(
        valueListenable: source.progressNotifier,
        builder: (context, progress, snapshot) {
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: subtitle),
                if (progress.total != 0 && sourceState != SourceState.locatingCountries) ...[
                  const WidgetSpan(child: SizedBox(width: 8)),
                  TextSpan(
                    text: '${progress.done}/${progress.total}',
                    style: TextStyle(color: theme.isDark ? Colors.white30 : Colors.black26),
                  ),
                ],
              ],
            ),
            softWrap: false,
            overflow: TextOverflow.fade,
            maxLines: 1,
          );
        },
      ),
    );
  }
}
