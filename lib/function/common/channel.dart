import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:streams_channel/streams_channel.dart';

class AvesMethodChannel extends MethodChannel {
  static bool kDebug = false;

  const AvesMethodChannel(super.name);

  @override
  Future<T?> invokeMethod<T>(String method, [arguments]) {
    if (kDebug) {
      debugPrint('$runtimeType platform call channel=$name method=$method arguments=$arguments');
    }
    return _invokeSafely(method, arguments);
  }

  /// 缺失平台通道实现（如桌面/非 Android 平台）时优雅降级，
  /// 返回 null 而非抛出 `MissingPluginException`。
  /// 各服务调用方对 null 通常都做了安全处理（返回默认值）。
  Future<T?> _invokeSafely<T>(String method, [arguments]) async {
    try {
      return await super.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      // 平台未实现该通道：静默降级
      return null;
    } on PlatformException {
      // 平台已实现但调用出错：抛给上层已有的 `on PlatformException` 处理
      rethrow;
    }
  }
}

class AvesStreamsChannel extends StreamsChannel {
  AvesStreamsChannel(super.name);

  @override
  Stream receiveBroadcastStream([arguments]) {
    if (AvesMethodChannel.kDebug) {
      debugPrint('$runtimeType platform call channel=$name arguments=$arguments');
    }
    // 缺失平台通道实现时返回空流，避免 `MissingPluginException` 崩溃
    return super.receiveBroadcastStream(arguments).handleError((error) {
      if (error is MissingPluginException) {
        // 平台未实现该通道：静默降级为空流
        return const <Object?>[];
      }
      throw error;
    });
  }
}

class AvesChannels {
  static const geocoding = 'com.naipingzai/flutter_media_view/geocoding';
  static const mediaSession = 'com.naipingzai/flutter_media_view/media_session';
  static const metadataFetch = 'com.naipingzai/flutter_media_view/metadata_fetch';

  static const _all = <MethodChannel>[
    AvesMethodChannel(geocoding),
    AvesMethodChannel(mediaSession),
    AvesMethodChannel(metadataFetch),
  ];

  static MethodChannel byName(String name) => _all.firstWhere((v) => v.name == name);
}
