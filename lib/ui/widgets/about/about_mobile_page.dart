import 'package:flutter_media_view/ui/widgets/about/app_ref.dart';
import 'package:flutter_media_view/ui/widgets/about/bug_report.dart';
import 'package:flutter_media_view/ui/widgets/about/credits.dart';
import 'package:flutter_media_view/ui/widgets/about/data_usage.dart';
import 'package:flutter_media_view/ui/widgets/about/licenses.dart';
import 'package:flutter_media_view/ui/widgets/about/translators.dart';
import 'package:flutter_media_view/ui/widgets/common/basic/insets.dart';
import 'package:flutter_media_view/ui/widgets/common/basic/scaffold.dart';
import 'package:flutter_media_view/ui/widgets/common/extensions/build_context.dart';
import 'package:flutter/material.dart';

class AboutMobilePage extends StatelessWidget {
  const AboutMobilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AvesScaffold(
      appBar: AppBar(
        title: Text(context.l10n.aboutPageTitle),
      ),
      body: GestureAreaProtectorStack(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      const AppReference(),
                      const Divider(),
                      const BugReport(),
                      const Divider(),
                      const AboutDataUsage(),
                      const Divider(),
                      const AboutCredits(),
                      const Divider(),
                      const AboutTranslators(),
                      const Divider(),
                    ],
                  ),
                ),
              ),
              const Licenses(),
              const BottomPaddingSliver(),
            ],
          ),
        ),
      ),
    );
  }
}
