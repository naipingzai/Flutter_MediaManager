import 'dart:convert';
import 'dart:io';

import 'package:flutter_media_view/core/app_flavor.dart';
import 'package:flutter_media_view/function/device/function_device.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_source.dart';
import 'package:flutter_media_view/function/locale/locales.dart';
import 'package:flutter_media_view/function/model/mime_types.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/function/services/device_service.dart';
import 'package:flutter_media_view/ui/theme/colors.dart';
import 'package:flutter_media_view/ui/theme/durations.dart';
import 'package:flutter_media_view/ui/theme/styles.dart';
import 'package:flutter_media_view/function/locale/fmv_locale.dart';
import 'package:flutter_media_view/function/utils/file_utils.dart';
import 'package:flutter_media_view/ui/about/app_ref.dart';
import 'package:flutter_media_view/ui/common/fmv_app.dart';
import 'package:flutter_media_view/ui/common/actions/common_action_mixins_feedback.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter_media_view/ui/filter/common_identity_fmv_filter_chip.dart';
import 'package:flutter_media_view/ui/common/identity/common_identity_buttons_outlined_button.dart';
import 'package:flutter_media_view/ui/settings/app_export_items.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class BugReport extends StatefulWidget {
  const BugReport({super.key});

  @override
  State<BugReport> createState() => _BugReportState();
}

class _BugReportState extends State<BugReport> {
  bool _showInstructions = false;

  @override
  Widget build(BuildContext context) {
    final animationDuration = context.select<DurationsData, Duration>((v) => v.expansionTileAnimation);
    return ExpansionPanelList(
      expansionCallback: (index, isExpanded) {
        setState(() => _showInstructions = isExpanded);
      },
      animationDuration: animationDuration,
      expandedHeaderPadding: EdgeInsets.zero,
      elevation: 0,
      children: [
        ExpansionPanel(
          headerBuilder: (context, isExpanded) => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: AlignmentDirectional.centerStart,
              child: Text(context.l10n.aboutBugSectionTitle, style: AStyles.knownTitleText),
            ),
          ),
          body: const BugReportContent(),
          isExpanded: _showInstructions,
          canTapOnHeader: true,
          backgroundColor: Colors.transparent,
        ),
      ],
    );
  }
}

class BugReportContent extends StatefulWidget {
  const BugReportContent({super.key});

  @override
  State<BugReportContent> createState() => _BugReportContentState();
}

class _BugReportContentState extends State<BugReportContent> with FeedbackMixin {
  late Future<String> _infoLoader;
  static const bugReportUrl = '${AppReference.fmvGithub}/issues/new?labels=type%3Abug&template=bug_report.yml';

  @override
  void initState() {
    super.initState();
    _infoLoader = _getInfo(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          _buildStep(1, l10n.aboutBugSaveLogInstruction, l10n.saveTooltip, _saveLogs),
          _buildStep(2, l10n.aboutBugReportInstruction, l10n.aboutBugReportButton, _goToGithub),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStep(int step, String text, String buttonText, VoidCallback onPressed) {
    final isMonochrome = settings.themeColorMode == FmvThemeColorMode.monochrome;
    final stepCountFormatter = settings.fmvLocale.decimalNumberFormat();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.fromBorderSide(
                BorderSide(
                  color: isMonochrome ? context.select<FmvColorsData, Color>((v) => v.neutral) : Theme.of(context).colorScheme.primary,
                  width: FmvFilterChip.outlineWidth,
                ),
              ),
              shape: BoxShape.circle,
            ),
            child: Text(stepCountFormatter.format(step)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
          const SizedBox(width: 8),
          FmvOutlinedButton(
            label: buttonText,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }

  Future<String> _getInfo(BuildContext context) async {
    final flavor = context.read<AppFlavor>().toString().split('.')[1];
    final packageInfo = await PackageInfo.fromPlatform();
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final mpc = await deviceService.getMediaPerformanceClass();
    final viewPhysicalSize = View.of(context).physicalSize;

    final ram = await deviceService.getRamSizes(<MemorySizeType>{.total});
    final heap = await deviceService.getHeapSizes(<MemorySizeType>{.max});
    final ramTotal = formatFileSize(FmvLocale.ascii, ram[MemorySizeType.total] ?? 0);
    final heapMax = formatFileSize(FmvLocale.ascii, heap[MemorySizeType.max] ?? 0);

    final supportsHdr = await windowService.supportsHdr();
    final supportsWideGamut = await windowService.supportsWideGamut();
    final crossWindowBlurEnabled = await windowService.isCrossWindowBlurEnabled();

    final connections = await Connectivity().checkConnectivity();
    final storageVolumes = await storageService.getStorageVolumes();
    final storageGrants = await storageService.getGrantedDirectories();

    final source = context.read<CollectionSource>();
    final entryCount = source.allEntries.length;
    final albumCount = source.rawAlbums.length;
    final tagCount = source.sortedTags.length;

    return [
      'Fmv: ${device.packageVersion}-$flavor, build ${packageInfo.buildNumber}, package=${device.packageName}, installer=${packageInfo.installerStore}',
      'Flutter: ${FlutterVersion.channel} ${FlutterVersion.version}',
      'Android: ${androidInfo.version.release}, API ${androidInfo.version.sdkInt}, MPC $mpc, build: ${androidInfo.display}',
      'Device: ${androidInfo.manufacturer} ${androidInfo.model}',
      'Memory: ram.total=$ramTotal, heap.max=$heapMax',
      'Screen: size.physical=${viewPhysicalSize.width.round()}x${viewPhysicalSize.height.round()}, HDR=$supportsHdr, wide gamut=$supportsWideGamut',
      'Graphics: size.logical=${MediaQuery.widthOf(context)}x${MediaQuery.heightOf(context)}, pixel ratio=${MediaQuery.devicePixelRatioOf(context)}, cross window blur=$crossWindowBlurEnabled',
      'Mobile services: ${mobileServices.isServiceAvailable ? 'ready' : 'not available'}, geocoder=${device.hasGeocoder}',
      'Connectivity: ${connections.map((v) => v.name).join(', ')}',
      'System locales: ${WidgetsBinding.instance.platformDispatcher.locales.join(', ')}',
      'Storage volumes: ${storageVolumes.map((v) => v.path).join(', ')}',
      'Storage grants: ${storageGrants.join(', ')}',
      'Error reporting: ${settings.isErrorReportingAllowed}',
      'Collection: $entryCount items, $albumCount albums, $tagCount tags',
    ].join('\n');
  }

  Future<void> _saveLogs() async {
    final contentInfo = await _infoLoader;
    final contentSettings = const JsonEncoder.withIndent('  ').convert(AppExportItem.settings.export(context.read<CollectionSource>()));
    final contentLog = (await Process.run('logcat', ['-d'])).stdout as String;

    final mixedContent = [
      contentInfo,
      contentSettings,
      contentLog,
    ].join('\n--------------------------------------------------------------------------------\n');

    final date = DateFormat('yyyyMMdd_HHmmss', kAsciiLocale).format(DateTime.now());
    final success = await storageService.createFile(
      basename: 'fmv-logs-$date',
      mimeType: MimeTypes.plainText,
      bytes: utf8.encode(mixedContent),
    );
    if (success != null) {
      if (success) {
        showFeedback(context, FeedbackType.info, context.l10n.genericSuccessFeedback);
      } else {
        showFeedback(context, FeedbackType.warn, context.l10n.genericFailureFeedback);
      }
    }
  }

  Future<void> _goToGithub() => FmvApp.launchUrl(bugReportUrl);
}
