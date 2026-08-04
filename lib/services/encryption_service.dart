import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

/// WebDAV 文件加密服务（内部自动加密，无需用户设置）
///
/// 使用 AES-256-CBC 模式加密文件内容。
/// 密钥从用户 WebDAV 凭证派生，每个用户的密钥不同。
/// 所有上传到 WebDAV 的文件（JSON 和媒体文件）都会被加密。
/// 加密后的文件格式：[Magic "ENC1" (4字节)] + [IV (16字节)] + [密文]
class EncryptionService {
  /// 加密文件的魔术标记 "ENC1"
  static const _magicHeader = [0x45, 0x4E, 0x43, 0x31]; // "ENC1"

  /// 内部默认密码（仅作为 fallback，实际应从用户凭证派生）
  static const _internalPassword = 'AMB-2026-SecureKey-7f3a';

  late encrypt.Key _key;
  String _currentKeySource = 'default';

  EncryptionService({String? userCredential}) {
    _initKey(userCredential ?? _internalPassword);
  }

  void _initKey(String credential) {
    _currentKeySource = credential;
    final hash = sha256.convert(utf8.encode(credential));
    _key = encrypt.Key(Uint8List.fromList(hash.bytes));
  }

  /// 从用户 WebDAV 凭证更新密钥
  ///
  /// 使用 serverUrl + username + token 组合作为密钥源
  void updateKeyFromCredential({
    required String serverUrl,
    required String username,
    required String token,
  }) {
    final credential = '$serverUrl|$username|$token';
    if (credential != _currentKeySource) {
      _initKey(credential);
    }
  }

  /// 加密是否启用（默认开启，用于 WebDAV 同步）
  bool _enabled = true;
  bool get isEncryptionEnabled => _enabled;
  set isEncryptionEnabled(bool value) => _enabled = value;

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
