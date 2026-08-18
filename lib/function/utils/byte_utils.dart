/// 字节工具，移植自 Android `utils/ByteUtils.kt` 与 `utils/CollectionUtils.kt`，
/// 无平台依赖，可复用于任何目标。
extension FmvByteUtils on List<int> {
  /// 字节数组转小写十六进制字符串，如 `[0xde, 0xad]` -> `'dead'`
  String toHex() => map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// 按 Boyer-Moore 算法在当前字节数组中查找 [pattern] 首次出现的下标，
  /// 未找到返回 -1。移植自 Android `utils/CollectionUtils.kt`。
  int indexOfBytes(List<int> pattern, [int start = 0]) {
    final n = length;
    final m = pattern.length;
    if (m == 0) return start;
    final badChar = List<int>.filled(256, 0);
    for (var i = 0; i < m; i++) {
      badChar[pattern[i] & 0xFF] = i;
    }
    var j = m - 1;
    var s = start;
    while (s <= n - m) {
      while (j >= 0 && pattern[j] == this[s + j]) {
        j--;
      }
      if (j < 0) return s;
      s += (j - badChar[this[s + j] & 0xFF]) > 1 ? j - badChar[this[s + j] & 0xFF] : 1;
      j = m - 1;
    }
    return -1;
  }

  /// 将字节按 UTF-16BE 解码为字符串（MP4 元数据常用编码）。
  /// 代理对（surrogate pair）按 UTF-16 规则合并，非法序列容错跳过。
  String toUtf16BeString() {
    final units = _beUnits(this);
    final buffer = StringBuffer();
    var i = 0;
    while (i < units.length) {
      final u = units[i];
      if (u >= 0xD800 && u <= 0xDBFF && i + 1 < units.length) {
        final next = units[i + 1];
        if (next >= 0xDC00 && next <= 0xDFFF) {
          buffer.writeCharCode(0x10000 + ((u - 0xD800) << 10) + (next - 0xDC00));
          i += 2;
          continue;
        }
      }
      buffer.writeCharCode(u);
      i++;
    }
    return buffer.toString();
  }

  static List<int> _beUnits(List<int> bytes) {
    final result = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      result.add((bytes[i] << 8) | bytes[i + 1]);
    }
    return result;
  }
}
