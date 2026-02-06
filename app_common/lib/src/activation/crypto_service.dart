import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../util/app_logger.dart';
import 'activation_storage.dart';

/// 加密服务
/// 用于验证 Ed25519 签名的邀请码
class CryptoService {
  CryptoService(this._configProvider);

  final AppConfigProvider _configProvider;

  String? _cachedPublicKey;

  /// 验证邀请码签名
  ///
  /// [inviteCode] 邀请码字符串，格式：VL-{TIER}-{PAYLOAD}.{SIGNATURE}
  ///
  /// 返回 payload 字典，如果验证失败返回 null
  Future<Map<String, dynamic>?> verifyInviteCode(String inviteCode) async {
    try {
      await AppLogger.debug(
        'Verifying invite code: $inviteCode',
        tag: 'CryptoService',
      );

      // 解析邀请码格式：VL-{TIER}-{PAYLOAD}.{SIGNATURE}
      final parts = inviteCode.split('.');
      if (parts.length != 2) {
        await AppLogger.warning(
          '邀请码格式错误：缺少签名部分 (expected 2 parts, got ${parts.length})',
          tag: 'CryptoService',
        );
        return null;
      }

      final prefixAndPayload = parts[0];
      final signatureB64 = parts[1];
      await AppLogger.debug(
        'Signature Base64URL (no padding): $signatureB64',
        tag: 'CryptoService',
      );
      await AppLogger.debug(
        'Signature Base64URL length: ${signatureB64.length}',
        tag: 'CryptoService',
      );

      // 解析前缀和 payload
      final prefixParts = prefixAndPayload.split('-');
      if (prefixParts.length < 3) {
        await AppLogger.warning(
          '邀请码格式错误：前缀格式不正确 (expected >= 3 parts, got ${prefixParts.length})',
          tag: 'CryptoService',
        );
        return null;
      }

      final payloadB64 = prefixParts[2];
      await AppLogger.debug(
        'Payload Base64URL (no padding): $payloadB64',
        tag: 'CryptoService',
      );
      await AppLogger.debug(
        'Payload Base64URL length: ${payloadB64.length}',
        tag: 'CryptoService',
      );

      // Base64URL 解码 payload
      final payloadB64Padded = _addBase64Padding(payloadB64);
      await AppLogger.debug(
        'Payload Base64URL (with padding): $payloadB64Padded',
        tag: 'CryptoService',
      );
      final payloadBytes = base64Url.decode(payloadB64Padded);
      await AppLogger.debug(
        'Payload bytes length: ${payloadBytes.length}',
        tag: 'CryptoService',
      );
      final payloadJson = utf8.decode(payloadBytes);
      await AppLogger.debug('Payload JSON: $payloadJson', tag: 'CryptoService');
      await AppLogger.debug(
        'Payload JSON length: ${payloadJson.length}',
        tag: 'CryptoService',
      );
      final payload = json.decode(payloadJson) as Map<String, dynamic>;

      // Base64URL 解码签名
      final signatureB64Padded = _addBase64Padding(signatureB64);
      await AppLogger.debug(
        'Signature Base64URL (with padding): $signatureB64Padded',
        tag: 'CryptoService',
      );
      final signatureBytes = base64Url.decode(signatureB64Padded);
      await AppLogger.debug(
        'Signature bytes length: ${signatureBytes.length}',
        tag: 'CryptoService',
      );

      // 验证签名
      final publicKey = await _getPublicKey();
      if (publicKey == null) {
        await AppLogger.warning('公钥未配置', tag: 'CryptoService');
        return null;
      }

      final messageBytes = utf8.encode(payloadJson);
      await AppLogger.debug(
        'Message bytes length for verification: ${messageBytes.length}',
        tag: 'CryptoService',
      );

      // 使用 Ed25519 算法验证签名
      final algorithm = Ed25519();
      try {
        final signature = Signature(signatureBytes, publicKey: publicKey);
        final isValid = await algorithm.verify(
          messageBytes,
          signature: signature,
        );

        if (!isValid) {
          await AppLogger.warning('签名验证失败', tag: 'CryptoService');
          return null;
        }

        await AppLogger.debug(
          'Signature verification successful!',
          tag: 'CryptoService',
        );
      } catch (e) {
        await AppLogger.error('签名验证异常: $e', tag: 'CryptoService');
        return null;
      }

      return payload;
    } catch (e, stackTrace) {
      await AppLogger.error(
        '验证邀请码异常: $e\n堆栈: $stackTrace',
        tag: 'CryptoService',
      );
      return null;
    }
  }

  /// 添加 Base64 填充
  String _addBase64Padding(String base64) {
    final padding = 4 - (base64.length % 4);
    if (padding == 4) return base64;
    return base64 + '=' * padding;
  }

  /// 获取公钥
  Future<SimplePublicKey?> _getPublicKey() async {
    // 使用缓存的公钥
    if (_cachedPublicKey != null) {
      try {
        final publicKeyBytes = base64.decode(_cachedPublicKey!);
        return SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      } catch (e) {
        await AppLogger.error('解析缓存的公钥失败: $e', tag: 'CryptoService');
        _cachedPublicKey = null;
      }
    }

    // 从配置读取公钥
    try {
      final publicKeyBase64 = _configProvider.invitePublicKey;

      if (publicKeyBase64.isEmpty ||
          publicKeyBase64 == 'YOUR_PUBLIC_KEY_HERE') {
        await AppLogger.warning(
          '公钥未配置，请运行脚本生成密钥对并配置到 app_config_*.json',
          tag: 'CryptoService',
        );
        return null;
      }

      // 缓存公钥
      _cachedPublicKey = publicKeyBase64;

      final publicKeyBytes = base64.decode(publicKeyBase64);
      return SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
    } catch (e) {
      await AppLogger.error('从配置读取公钥失败: $e', tag: 'CryptoService');
      return null;
    }
  }
}
