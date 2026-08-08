import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

// 加密服务
class EncryptionService {
  /// 加密文件的魔术标记 "ENC1"
  static const _magicHeader = [0x45, 0x4E, 0x43, 0x31];

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

  Uint8List encryptText(String plainText) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return Uint8List.fromList(
        [..._magicHeader, ...iv.bytes, ...encrypted.bytes]);
  }

  String decryptText(Uint8List data) {
    if (!_hasMagicHeader(data)) {
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
      return utf8.decode(data);
    }
  }

  Uint8List encryptBytes(Uint8List plainBytes) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter =
        encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);
    return Uint8List.fromList(
        [..._magicHeader, ...iv.bytes, ...encrypted.bytes]);
  }

  Uint8List decryptBytes(Uint8List encryptedData) {
    if (!_hasMagicHeader(encryptedData)) {
      return encryptedData;
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
