import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// 流式哈希工具，移植自 Android `utils/HashUtils.kt`，无平台依赖，可复用于任何目标。
class HashUtils {
  HashUtils._();

  /// 计算流式哈希，[algorithmKey] 支持 `md5` / `sha1` / `sha256`，
  /// 返回小写十六进制摘要（与 Android 端输出一致）。
  static Future<String> getHash(Stream<List<int>> input, String algorithmKey) async {
    final sink = _HashSink(algorithmKey);
    await input.forEach(sink.add);
    return sink.close();
  }

  /// 一次性计算字节哈希
  static String hashBytes(List<int> bytes, String algorithmKey) => _digestFor(algorithmKey).convert(bytes).toString();

  static crypto.Hash _digestFor(String algorithmKey) => switch (algorithmKey) {
        'md5' => crypto.md5,
        'sha1' => crypto.sha1,
        'sha256' => crypto.sha256,
        _ => throw ArgumentError('unsupported hash algorithm: $algorithmKey'),
      };
}

class _HashSink {
  final crypto.Hash _hash;

  _HashSink(String algorithmKey) : _hash = HashUtils._digestFor(algorithmKey);

  final BytesBuilder _builder = BytesBuilder(copy: false);

  void add(List<int> data) => _builder.add(data);

  String close() => _hash.convert(_builder.takeBytes()).toString();
}

/// 便于与文件/网络流配合的便捷方法
extension HashStreamUtils on Stream<List<int>> {
  Future<String> computeHash(String algorithmKey) => HashUtils.getHash(this, algorithmKey);
}
