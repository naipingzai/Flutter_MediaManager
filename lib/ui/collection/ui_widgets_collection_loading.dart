import 'package:flutter_media_view/function/settings/function_settings.dart';
import 'package:flutter_media_view/function/source/function_source_collection_source.dart';
import 'package:flutter_media_view/function/source/function_source_events.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_action_mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/ui_widgets_common_identity_empty.dart';
import 'package:flutter/material.dart';

class LoadingEmptyContent extends StatelessWidget {
  final CollectionSource source;

  const LoadingEmptyContent({
    super.key,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final itemCountFormatter = settings.avesLocale.decimalNumberFormat();
    final progressTextStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .5),
      fontSize: 18,
    );

    return EmptyContent(
      text: context.l10n.sourceStateLoading,
      bottom: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const ReportProgressIndicator(),
            ValueListenableBuilder<ProgressEvent>(
              valueListenable: source.progressNotifier,
              builder: (context, progress, snapshot) {
                final done = progress.done;
                return done > 0
                    ? Text(
                        itemCountFormatter.format(done),
                        style: progressTextStyle,
                      )
                    : const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
  }
}
