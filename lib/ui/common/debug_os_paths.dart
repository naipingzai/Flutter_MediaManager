import 'dart:collection';

import 'package:flutter_media_view/function/device/android_debug_service.dart';
import 'package:flutter_media_view/ui/common/common_identity_aves_expansion_tile.dart';
import 'package:flutter_media_view/ui/viewer/widgets_viewer_info_common.dart';
import 'package:flutter/material.dart';

class DebugOSPathSection extends StatefulWidget {
  const DebugOSPathSection({super.key});

  @override
  State<DebugOSPathSection> createState() => _DebugOSPathSectionState();
}

class _DebugOSPathSectionState extends State<DebugOSPathSection> with AutomaticKeepAliveClientMixin {
  late Future<Map> _loader;

  @override
  void initState() {
    super.initState();
    _loader = AndroidDebugService.getContextDirs();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FmvExpansionTile(
      title: 'OS Paths',
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          child: FutureBuilder<Map>(
            future: _loader,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text(snapshot.error.toString());
              if (snapshot.connectionState != ConnectionState.done) return const SizedBox();
              final data = SplayTreeMap.of(snapshot.data!.map((k, v) => MapEntry(k.toString(), v?.toString() ?? 'null')));
              return InfoRowGroup(info: data);
            },
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
