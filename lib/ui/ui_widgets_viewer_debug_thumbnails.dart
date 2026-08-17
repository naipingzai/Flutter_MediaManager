import 'dart:typed_data';

import 'package:flutter_media_view/ui/ui_image_providers_thumbnail_provider.dart';
import 'package:flutter_media_view/function/function_entry.dart';
import 'package:flutter_media_view/function/function_entry_extensions_images.dart';
import 'package:flutter_media_view/function/function_android_debug_service.dart';
import 'package:flutter_media_view/ui/ui_widgets_common_identity_aves_expansion_tile.dart';
import 'package:flutter/material.dart';

class ThumbnailsTab extends StatefulWidget {
  final AvesEntry entry;

  const ThumbnailsTab({
    super.key,
    required this.entry,
  });

  @override
  State<ThumbnailsTab> createState() => _ThumbnailsTabState();
}

class _ThumbnailsTabState extends State<ThumbnailsTab> {
  late final Future<List<MapEntry<ThumbnailMethod, Uint8List?>>> _byMethodLoader;

  AvesEntry get entry => widget.entry;

  @override
  void initState() {
    super.initState();
    final providerKey = ThumbnailProviderKey(
      uri: entry.uri,
      mimeType: entry.mimeType,
      pageId: entry.pageId,
      rotationDegrees: entry.rotationDegrees,
      isFlipped: entry.isFlipped,
      dateModifiedMillis: entry.dateModifiedMillis ?? -1,
    );
    _byMethodLoader = Future.wait(
      ThumbnailMethod.values.map((method) async {
        final bytes = await AndroidDebugService.getThumbnail(providerKey, method);
        return MapEntry(method, bytes);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        AvesExpansionTile(
          title: 'Cached',
          children: entry.cachedThumbnails
              .expand(
                (provider) => [
                  Text('Thumb extent: ${provider.key.extent}'),
                  Center(
                    child: Image(
                      image: provider,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        return Container(
                          foregroundDecoration: const BoxDecoration(
                            border: Border.fromBorderSide(
                              BorderSide(
                                color: Colors.amber,
                                width: .1,
                              ),
                            ),
                          ),
                          child: child,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              )
              .toList(),
        ),
        FutureBuilder<List<MapEntry<ThumbnailMethod, Uint8List?>>>(
          future: _byMethodLoader,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(snapshot.error.toString());
            if (snapshot.connectionState != ConnectionState.done) return const SizedBox();

            final result = snapshot.data!;

            return AvesExpansionTile(
              title: 'By method',
              children: result.expand((kv) {
                final method = kv.key;
                final bytes = kv.value;
                return <Widget>[
                  Text('$method'),
                  if (bytes != null) Image.memory(bytes) else const Text('null'),
                ];
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
