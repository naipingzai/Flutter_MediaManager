import 'package:flutter_media_view/function/device/function_device.dart';
import 'package:flutter_media_view/function/locale/locales.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/about/widgets_policy_page.dart';
import 'package:flutter_media_view/ui/common/common_basic_link_chip.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/common_identity_fmv_logo.dart';
import 'package:flutter/material.dart';

class AppReference extends StatelessWidget {
  static const fmvGithub = 'https://github.com/naipingzai/Flutter_MediaManager';
  static const fmvFaq = '$fmvGithub/wiki/FAQ';

  const AppReference({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          _buildFmvLine(context),
          const SizedBox(height: 16),
          Wrap(
            alignment: .center,
            spacing: 16,
            crossAxisAlignment: .center,
            children: AppReference.buildLinks(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFmvLine(BuildContext context) {
    final localeName = context.localeName;
    final textScaler = MediaQuery.textScalerOf(context);
    return Row(
      mainAxisSize: .min,
      children: [
        FmvLogo(
          size: textScaler.scale(_getAppTitleStyle(localeName).fontSize!) * 1.3,
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.appName,
          style: _getAppTitleStyle(localeName),
        ),
        const SizedBox(width: 8),
        Text(
          device.packageVersion,
          style: _getAppTitleStyle(localeName),
        ),
      ],
    );
  }

  TextStyle _getAppTitleStyle(String localeName) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.normal,
    letterSpacing: canHaveLetterSpacing(localeName) ? 1 : 0,
    fontFeatures: const [FontFeature.enable('smcp')],
  );

  static List<Widget> buildLinks(BuildContext context) {
    final l10n = context.l10n;
    return [
      const LinkChip(
        leading: Icon(
          AIcons.github,
          size: 24,
        ),
        text: 'GitHub',
        urlString: AppReference.fmvGithub,
      ),
      LinkChip(
        leading: const Icon(
          AIcons.legal,
          size: 22,
        ),
        text: l10n.aboutLinkLicense,
        urlString: '${AppReference.fmvGithub}/blob/main/LICENSE',
      ),
      LinkChip(
        leading: const Icon(
          AIcons.privacy,
          size: 22,
        ),
        text: l10n.aboutLinkPolicy,
        onTap: () => _goToPolicyPage(context),
      ),
    ];
  }

  static void _goToPolicyPage(BuildContext context) {
    Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: PolicyPage.routeName),
        builder: (context) => const PolicyPage(),
      ),
    );
  }
}
