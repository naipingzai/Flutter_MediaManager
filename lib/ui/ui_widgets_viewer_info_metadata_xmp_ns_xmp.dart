import 'package:flutter_media_view/function/function_ref_metadata_xmp.dart';
import 'package:flutter_media_view/function/function_mime_types.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/ui_widgets_viewer_info_common.dart';
import 'package:flutter_media_view/ui/ui_widgets_viewer_info_embedded_notifications.dart';
import 'package:flutter_media_view/ui/ui_widgets_viewer_info_metadata_xmp_namespaces.dart';

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
