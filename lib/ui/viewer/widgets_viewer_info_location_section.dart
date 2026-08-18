import 'package:flutter_media_view/app_mode.dart';
import 'package:flutter_media_view/function/entry/entry.dart';
import 'package:flutter_media_view/function/entry/extensions_location.dart';
import 'package:flutter_media_view/function/filters/covered_location.dart';
import 'package:flutter_media_view/function/settings/enums_coordinate_format.dart';
import 'package:flutter_media_view/function/settings/settings.dart';
import 'package:flutter_media_view/function/source/collection_lens.dart';
import 'package:flutter_media_view/function/common/services.dart';
import 'package:flutter_media_view/ui/theme/icons.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/filter/widgets_common_identity_fmv_filter_chip.dart';
import 'package:flutter_media_view/ui/common/common_map_geo_map.dart';
import 'package:flutter_media_view/ui/common/common_map_map_action_delegate.dart';
import 'package:flutter_media_view/ui/common/common_providers_map_theme_provider.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';
import 'package:flutter_media_view/ui/common/map_map_page.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_info_common.dart';
import 'package:flutter_media_view_map/flutter_media_view_map.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LocationSection extends StatefulWidget {
  final CollectionLens? collection;
  final FmvEntry entry;
  final bool showTitle;
  final ValueNotifier<bool> isScrollingNotifier;
  final AFilterCallback onFilterSelection;

  const LocationSection({
    super.key,
    required this.collection,
    required this.entry,
    required this.showTitle,
    required this.isScrollingNotifier,
    required this.onFilterSelection,
  });

  @override
  State<LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends State<LocationSection> {
  final FmvMapController _mapController = FmvMapController();

  CollectionLens? get collection => widget.collection;

  FmvEntry get entry => widget.entry;

  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
  }

  @override
  void didUpdateWidget(covariant LocationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    _mapController.dispose();
    super.dispose();
  }

  void _registerWidget(LocationSection widget) {
    widget.entry.metadataChangeNotifier.addListener(_onMetadataChanged);
  }

  void _unregisterWidget(LocationSection widget) {
    widget.entry.metadataChangeNotifier.removeListener(_onMetadataChanged);
  }

  @override
  Widget build(BuildContext context) {
    if (!entry.hasGps) return const SizedBox();

    final canNavigate = context.select<ValueNotifier<AppMode>, bool>((v) => v.value.canNavigate);
    return NotificationListener(
      onNotification: (notification) {
        if (notification is OpenMapAppNotification) {
          _openMapApp();
          return true;
        }
        return false;
      },
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (widget.showTitle) const SectionRow(icon: AIcons.location),
          MapTheme(
            interactive: false,
            showCoordinateFilter: false,
            navigationButton: canNavigate ? MapNavigationButton.map : MapNavigationButton.none,
            visualDensity: VisualDensity.compact,
            mapHeight: 200,
            child: GeoMap(
              controller: _mapController,
              entries: [entry],
              availableSize: MediaQuery.sizeOf(context),
              isAnimatingNotifier: widget.isScrollingNotifier,
              onUserZoomChange: (zoom) => settings.infoMapZoom = zoom.roundToDouble(),
              onMarkerTap: collection != null && canNavigate ? (location, entry) => _openMapPage(context) : null,
              openMapPage: collection != null ? _openMapPage : null,
            ),
          ),
          ListenableBuilder(
            listenable: entry.addressChangeNotifier,
            builder: (context, child) {
              final filters = <LocationFilter>[];
              if (entry.hasAddress) {
                final address = entry.addressDetails!;
                final country = address.countryName;
                if (country != null && country.isNotEmpty) filters.add(LocationFilter(LocationLevel.country, '$country${LocationFilter.locationSeparator}${address.countryCode}'));
                final state = address.stateName;
                if (state != null && state.isNotEmpty) filters.add(LocationFilter(LocationLevel.state, '$state${LocationFilter.locationSeparator}${address.stateCode}'));
                final place = address.place;
                if (place != null && place.isNotEmpty) filters.add(LocationFilter(LocationLevel.place, place));
              }

              return Column(
                crossAxisAlignment: .start,
                children: [
                  _AddressInfoGroup(entry: entry),
                  if (filters.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: FmvFilterChip.outlineWidth / 2) + const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: filters
                            .map(
                              (filter) => FmvFilterChip(
                                filter: filter,
                                onTap: widget.onFilterSelection,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openMapPage(BuildContext context) async {
    final baseCollection = collection;
    if (baseCollection == null) return;

    final mapCollection = baseCollection.copyWith(
      listenToSource: true,
      fixedSelection: baseCollection.sortedEntries.where((entry) => entry.hasGps).toList(),
    );
    await Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: MapPage.routeName),
        builder: (context) => MapPage(
          collection: mapCollection,
          initialEntry: entry,
        ),
      ),
    );
  }

  Future<void> _openMapApp() async {
    final latLng = entry.latLng;
    if (latLng != null) {
      await appService.openMap(latLng).then((success) {
        if (!success) showNoMatchingAppDialog(context);
      });
    }
  }

  void _onMetadataChanged() {
    setState(() {});

    final location = entry.latLng;
    if (location != null) {
      _mapController.notifyMarkerLocationChange();
      _mapController.moveTo(location);
    }
  }
}

class _AddressInfoGroup extends StatefulWidget {
  final FmvEntry entry;

  const _AddressInfoGroup({required this.entry});

  @override
  State<_AddressInfoGroup> createState() => _AddressInfoGroupState();
}

class _AddressInfoGroupState extends State<_AddressInfoGroup> {
  late Future<String?> _addressLineLoader;

  FmvEntry get entry => widget.entry;

  @override
  void initState() {
    super.initState();
    _addressLineLoader = availability.canLocatePlaces.then((connected) {
      if (connected) {
        return entry.findAddressLine(geocoderLocale: settings.fmvLocale);
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _addressLineLoader,
      builder: (context, snapshot) {
        final fullAddress = !snapshot.hasError && snapshot.connectionState == ConnectionState.done ? snapshot.data : null;
        final address = fullAddress ?? entry.shortAddress;
        final l10n = context.l10n;
        return InfoRowGroup(
          info: {
            l10n.viewerInfoLabelCoordinates: settings.coordinateFormat.format(context, entry.latLng!),
            if (address.isNotEmpty) l10n.viewerInfoLabelAddress: address,
          },
        );
      },
    );
  }
}
