import 'package:fmv/ui/about/app_ref.dart';
import 'package:fmv/ui/about/bug_report.dart';
import 'package:fmv/ui/about/credits.dart';
import 'package:fmv/ui/about/data_usage.dart';
import 'package:fmv/ui/about/licenses.dart';
import 'package:fmv/ui/about/translators.dart';
import 'package:fmv/ui/common/basic/basic_insets.dart';
import 'package:fmv/ui/common/basic/basic_scaffold.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:flutter/material.dart';

class AboutMobilePage extends StatelessWidget {
  const AboutMobilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FmvScaffold(
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
