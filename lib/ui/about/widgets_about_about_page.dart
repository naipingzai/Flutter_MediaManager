import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/ui/about/widgets_about_about_mobile_page.dart';
import 'package:flutter_media_view/ui/about/widgets_about_about_tv_page.dart';
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  static const routeName = '/about';

  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (settings.useTvLayout) {
      return const AboutTvPage();
    } else {
      return const AboutMobilePage();
    }
  }
}
