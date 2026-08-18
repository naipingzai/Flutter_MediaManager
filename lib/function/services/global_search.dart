import 'dart:ui';

import 'package:flutter_media_view/function/entry/sort.dart';
import 'package:flutter_media_view/function/common/channel.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/theme/format.dart';
import 'package:flutter_media_view/function/locale/fmv_locale.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

class GlobalSearch {
  static const _platform = FmvMethodChannel('com.naipingzai/flutter_media_view/global_search');

  static Future<void> registerCallback() async {
    try {
      await _platform.invokeMethod('registerCallback', <String, Object?>{
        // callback needs to be annotated with `@pragma('vm:entry-point')` to work in release mode
        'callbackHandle': PluginUtilities.getCallbackHandle(_init)?.toRawHandle(),
      });
    } on PlatformException catch (e, stack) {
      await reportService.recordError(e, stack);
    }
  }
}

@pragma('vm:entry-point')
Future<void> _init() async {
  WidgetsFlutterBinding.ensureInitialized();

  // service initialization for path context, database
  initPlatformServices();
  await localMediaDb.init();

  // `intl` initialization for date formatting
  await initializeDateFormatting();

  const _channel = FmvMethodChannel('com.naipingzai/flutter_media_view/global_search_background');
  _channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'getSuggestions':
        return await _getSuggestions(call.arguments);
      default:
        throw PlatformException(code: 'not-implemented', message: 'failed to handle method=${call.method}');
    }
  });
  await _channel.invokeMethod('initialized');
}

Future<List<Map<String, String?>>> _getSuggestions(Object? args) async {
  final suggestions = <Map<String, String?>>[];
  if (args is Map) {
    final query = args['query'];
    final localeName = args['locale'];
    final use24hour = args['use24hour'];
    debugPrint('getSuggestions query=$query, localeName=$localeName use24hour=$use24hour');

    if (query is String && localeName is String) {
      final entries = (await localMediaDb.searchLiveEntries(query, limit: 9)).toList();
      final catalogMetadata = await localMediaDb.loadCatalogMetadataById(entries.map((entry) => entry.id).toSet());
      catalogMetadata.forEach((metadata) => entries.firstWhereOrNull((entry) => entry.id == metadata.id)?.catalogMetadata = metadata);
      entries.sort(FmvEntrySort.compareByDate);

      // TODO TLAD [calendar] try whether `settings.fmvLocale` is accessible, after:
      //   await settings.init(monitorPlatformSettings: false, shouldSanitize: false);
      final locale = FmvLocale(
        languageTag: localeName,
        calendar: ACalendar.gregorian,
        forceWesternArabicNumerals: false,
      );

      suggestions.addAll(
        entries.map((entry) {
          final date = entry.bestDate;
          return {
            'data': entry.uri,
            'mimeType': entry.mimeType,
            'title': entry.bestTitle,
            'subtitle': date != null ? formatDateTime(date, locale, use24hour) : null,
            'iconUri': entry.uri,
          };
        }),
      );
    }
  }
  return suggestions;
}
