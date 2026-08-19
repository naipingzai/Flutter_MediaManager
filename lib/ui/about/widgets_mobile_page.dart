import 'package:flutter_media_view/ui/about/widgets_app_ref.dart';
import 'package:flutter_media_view/ui/about/widgets_bug_report.dart';
import 'package:flutter_media_view/ui/about/widgets_about_credits.dart';
import 'package:flutter_media_view/ui/about/widgets_data_usage.dart';
import 'package:flutter_media_view/ui/about/widgets_about_licenses.dart';
import 'package:flutter_media_view/ui/about/widgets_about_translators.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_insets.dart';
import 'package:flutter_media_view/ui/common/basic/common_basic_scaffold.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
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
