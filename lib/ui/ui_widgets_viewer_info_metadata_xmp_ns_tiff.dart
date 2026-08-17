import 'package:flutter_media_view/function/function_metadata_exif.dart';
import 'package:flutter_media_view/function/function_ref_metadata_xmp.dart';
import 'package:flutter_media_view/ui/ui_widgets_viewer_info_metadata_xmp_namespaces.dart';

// cf https://github.com/adobe/xmp-docs/blob/master/XMPNamespaces/tiff.md
class XmpTiffNamespace extends XmpNamespace {
  XmpTiffNamespace({required super.schemaRegistryPrefixes, required super.rawProps}) : super(nsUri: XmpNamespaces.tiff);

  @override
  String formatValue(XmpProp prop) {
    final value = prop.value;
    switch (prop.path) {
      case 'tiff:Compression':
        return Exif.getCompressionDescription(value);
      case 'tiff:Orientation':
        return Exif.getOrientationDescription(value);
      case 'tiff:PhotometricInterpretation':
        return Exif.getPhotometricInterpretationDescription(value);
      case 'tiff:PlanarConfiguration':
        return Exif.getPlanarConfigurationDescription(value);
      case 'tiff:ResolutionUnit':
        return Exif.getResolutionUnitDescription(value);
      case 'tiff:YCbCrPositioning':
        return Exif.getYCbCrPositioningDescription(value);
    }
    return value;
  }
}
