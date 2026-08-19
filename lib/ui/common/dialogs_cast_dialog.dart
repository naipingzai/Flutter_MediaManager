import 'package:flutter_media_view/function/services/function_upnp.dart';
import 'package:flutter_media_view/ui/common/common_extensions_build_context.dart';
import 'package:flutter_media_view/ui/common/dialogs_fmv_dialog.dart';
import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';

class CastDialog extends StatefulWidget {
  static const routeName = '/dialog/cast';

  const CastDialog({super.key});

  @override
  State<CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends State<CastDialog> {
  final DLNAManager _dlnaManager = DLNAManager();
  final Map<String, DLNADevice> _seenRenderers = {};

  @override
  void initState() {
    super.initState();

    _dlnaManager.start().then((deviceManager) {
      deviceManager.devices.stream.listen((devices) {
        _seenRenderers.addAll(
          Map.fromEntries(
            devices.entries.where((kv) => kv.value.info.deviceType == Upnp.upnpDeviceTypeMediaRenderer).map((kv) {
              final device = kv.value;
              return MapEntry(device.info.friendlyName, device);
            }),
          ),
        );
        setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _dlnaManager.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FmvDialog(
      title: context.l10n.castDialogTitle,
      scrollableContent: [
        if (_seenRenderers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ..._seenRenderers.values.map(
          (dev) => ListTile(
            title: Text(dev.info.friendlyName),
            onTap: () => Navigator.maybeOf(context)?.pop<DLNADevice>(dev),
          ),
        ),
      ],
      actions: const [
        CancelButton(),
      ],
    );
  }
}
