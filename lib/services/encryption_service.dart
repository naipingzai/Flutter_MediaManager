import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

/// WebDAV 文件加密服务（内部自动加密，无需用户设置）
///
/// 使用 AES-256-CBC 模式加密文件内容。
/// 密码在内部生成，用户无感知。
/// 所有上传到 WebDAV 的文件（JSON 和媒体文件）都会被加密。
/// 加密后的文件格式：[Magic "ENC1" (4字节)] + [IV (16字节)] + [密文]
class EncryptionService {
  /// 加密文件的魔术标记 "ENC1"
  static const _magicHeader = [0x45, 0x4E, 0x43, 0x31]; // "ENC1"

  /// 内部加密密码（永不暴露给用户）
  static const _internalPassword = 'AMB-2026-SecureKey-7f3a';

  late final encrypt.Key _key;

  EncryptionService() {
    final hash = sha256.convert(utf8.encode(_internalPassword));
    _key = encrypt.Key(Uint8List.fromList(hash.bytes));
  }

  /// 加密始终启用
  bool get isEncryptionEnabled => true;

  /// 加密文本内容（用于 data.json 等文本文件）
  Uint8List encryptText(String plainText) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return Uint8List.fromList(
        [..._magicHeader, ...iv.bytes, ...encrypted.bytes]);
  }

  /// 解密文本内容（用于读取 data.json 等文本文件）
  String decryptText(Uint8List data) {
    // 检查魔术标记 "ENC1"
    if (!_hasMagicHeader(data)) {
      // 未加密的旧数据，直接读取
      return utf8.decode(data);
    }
    try {
      final iv = encrypt.IV(Uint8List.fromList(data.sublist(4, 4 + 16)));
      final encryptedData =
          encrypt.Encrypted(Uint8List.fromList(data.sublist(4 + 16)));
      final encrypter =
          encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
      return encrypter.decrypt(encryptedData, iv: iv);
    } catch (e) {
      // 解密失败，尝试作为明文读取
      return utf8.decode(data);
    }
  }

  /// 加密二进制内容（用于图片、视频等媒体文件）
  Uint8List encryptBytes(Uint8List plainBytes) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);
    return Uint8List.fromList(
        [..._magicHeader, ...iv.bytes, ...encrypted.bytes]);
  }

  /// 解密二进制内容（用于下载图片、视频等媒体文件）
  Uint8List decryptBytes(Uint8List encryptedData) {
    if (!_hasMagicHeader(encryptedData)) {
      return encryptedData; // 未加密数据，直接返回
    }
    try {
      final iv =
          encrypt.IV(Uint8List.fromList(encryptedData.sublist(4, 4 + 16)));
      final data =
          encrypt.Encrypted(Uint8List.fromList(encryptedData.sublist(4 + 16)));
      final encrypter =
          encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
      return Uint8List.fromList(encrypter.decryptBytes(data, iv: iv));
    } catch (e) {
      return encryptedData;
    }
  }

  bool _hasMagicHeader(Uint8List data) {
    if (data.length < 4) return false;
    return data[0] == _magicHeader[0] &&
        data[1] == _magicHeader[1] &&
        data[2] == _magicHeader[2] &&
        data[3] == _magicHeader[3];
  }
}
