import 'package:flutter_media_view/function/metadata/function_ref_metadata_xmp.dart';
import 'package:flutter_media_view/ui/viewer/info_metadata_xmp_namespaces.dart';

class XmpCrsNamespace extends XmpNamespace {
  XmpCrsNamespace({required super.schemaRegistryPrefixes, required super.rawProps}) : super(nsUri: XmpNamespaces.crs);

  @override
  late final List<XmpCardData> cards = [
    XmpCardData(RegExp(nsPrefix + r'CircularGradientBasedCorrections\[(\d+)\]/(.*)')),
    XmpCardData(
      RegExp(nsPrefix + r'GradientBasedCorrections\[(\d+)\]/(.*)'),
      cards: [
        XmpCardData(RegExp(nsPrefix + r'CorrectionMasks\[(\d+)\]/(.*)')),
        XmpCardData(RegExp(nsPrefix + r'CorrectionRangeMask/(.*)')),
      ],
    ),
    XmpCardData(
      RegExp(nsPrefix + r'Look/(.*)'),
      cards: [
        XmpCardData(RegExp(nsPrefix + r'Parameters/(.*)')),
      ],
    ),
    XmpCardData(
      RegExp(nsPrefix + r'MaskGroupBasedCorrections\[(\d+)\]/(.*)'),
      cards: [
        XmpCardData(
          RegExp(nsPrefix + r'CorrectionMasks\[(\d+)\]/(.*)'),
          cards: [
            XmpCardData(RegExp(nsPrefix + r'CorrectionRangeMask/(.*)')),
            XmpCardData(RegExp(nsPrefix + r'Gesture\[(\d+)\]/(.*)')),
            XmpCardData(RegExp(nsPrefix + r'Masks\[(\d+)\]/(.*)')),
          ],
        ),
      ],
    ),
    XmpCardData(
      RegExp(nsPrefix + r'PaintBasedCorrections\[(\d+)\]/(.*)'),
      cards: [
        XmpCardData(RegExp(nsPrefix + r'CorrectionMasks\[(\d+)\]/(.*)')),
        XmpCardData(RegExp(nsPrefix + r'CorrectionRangeMask/(.*)')),
      ],
    ),
    XmpCardData(
      RegExp(nsPrefix + r'RetouchAreas\[(\d+)\]/(.*)'),
      cards: [
        XmpCardData(RegExp(nsPrefix + r'Masks\[(\d+)\]/(.*)')),
      ],
    ),
    XmpCardData(RegExp(nsPrefix + r'RangeMaskMapInfo/' + nsPrefix + r'RangeMaskMapInfo/(.*)')),
  ];
}
