import 'package:flutter_media_view/function/metadata/function_ref_metadata_xmp.dart';
import 'package:flutter_media_view/function/model/mime_types.dart';
import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:flutter_media_view/ui/viewer/info/common.dart';
import 'package:flutter_media_view/ui/viewer/info/embedded_notifications.dart';
import 'package:flutter_media_view/ui/viewer/info/metadata_xmp_namespaces.dart';

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
