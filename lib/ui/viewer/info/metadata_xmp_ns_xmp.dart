import 'package:fmv/function/metadata/function_ref_metadata_xmp.dart';
import 'package:fmv/function/model/mime_types.dart';
import 'package:fmv/ui/common/extensions_build_context.dart';
import 'package:fmv/ui/viewer/info/common.dart';
import 'package:fmv/ui/viewer/info/embedded_notifications.dart';
import 'package:fmv/ui/viewer/info/metadata_xmp_namespaces.dart';

class XmpBasicNamespace extends XmpNamespace {
  XmpBasicNamespace({required super.schemaRegistryPrefixes, required super.rawProps}) : super(nsUri: XmpNamespaces.xmp);

  @override
  late final List<XmpCardData> cards = [
    XmpCardData(
      RegExp(nsPrefix + r'Thumbnails\[(\d+)\]/(.*)'),
      spanBuilders: (index, struct) {
        return {
          if (struct.containsKey('xmpGImg:image'))
            'Image': InfoRowGroup.linkSpanBuilder(
              linkText: (context) => context.l10n.viewerInfoOpenLinkText,
              onTap: (context) => OpenEmbeddedDataNotification.xmp(
                props: [
                  const [XmpNamespaces.xmp, 'Thumbnails'],
                  index,
                  const [XmpNamespaces.xmpGImg, 'image'],
                ],
                mimeType: MimeTypes.jpeg,
              ).dispatch(context),
            ),
        };
      },
    ),
  ];
}
