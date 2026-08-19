import 'package:flutter_media_view/function/locale/locales.dart';
import 'package:flutter_media_view/function/model/mime_types.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/about/bug_report.dart';
import 'package:flutter_media_view/ui/common/actions/common_action_mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_fmv_expansion_tile.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_buttons_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeError extends StatefulWidget {
  final Object error;
  final StackTrace stack;

  const HomeError({
    super.key,
    required this.error,
    required this.stack,
  });

  @override
  State<HomeError> createState() => _HomeErrorState();
}

class _HomeErrorState extends State<HomeError> with FeedbackMixin {
  final ValueNotifier<String?> _expandedNotifier = ValueNotifier(null);

  @override
  void dispose() {
    _expandedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  FmvExpansionTile(
                    title: 'Error',
                    expandedNotifier: _expandedNotifier,
                    showHighlight: false,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: SelectableText(
                          '${widget.error}:\n${widget.stack}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  FmvExpansionTile(
                    title: l10n.aboutBugSectionTitle,
                    expandedNotifier: _expandedNotifier,
                    showHighlight: false,
                    children: const [BugReportContent()],
                  ),
                  FmvExpansionTile(
                    title: l10n.aboutDataUsageDatabase,
                    expandedNotifier: _expandedNotifier,
                    showHighlight: false,
                    children: [
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: FmvOutlinedButton(
                              label: l10n.settingsActionExport,
                              onPressed: () async {
                                final sourcePath = await localMediaDb.path;
                                final date = DateFormat('yyyyMMdd_HHmmss', kAsciiLocale).format(DateTime.now());
                                final success = await storageService.copyFile(
                                  basename: 'fmv-database-$date',
                                  mimeType: MimeTypes.sqlite3,
                                  sourceUri: Uri.file(sourcePath).toString(),
                                );
                                if (success != null) {
                                  if (success) {
                                    showFeedback(context, FeedbackType.info, context.l10n.genericSuccessFeedback);
                                  } else {
                                    showFeedback(context, FeedbackType.warn, context.l10n.genericFailureFeedback);
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
