import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../http/http_client_factory.dart';
import '../util/app_logger.dart';
import '../util/client_id_service.dart';
import 'activation_models.dart';
import 'activation_storage.dart';
import 'crypto_service.dart';

/// 激活服务
/// 管理用户等级和激活状态
class ActivationService {
  ActivationService(this._storage, this._configProvider);

  final ActivationStorage _storage;
  final AppConfigProvider _configProvider;

  // 缓存当前等级
  UserTier? _cachedTier;

  /// 获取当前等级（仅读取本地存储）
  UserTier getCurrentTier() {
    if (_cachedTier != null) {
      return _cachedTier!;
    }

    // 同步读取本地存储时返回free，需要通过getCurrentTierAsync初始化
    return UserTier.free;
  }

  /// 获取当前等级（异步版本，用于初始化）
  Future<UserTier> getCurrentTierAsync() async {
    final tierStr = await _storage.getTier();
    final tier = _parseTier(tierStr);
    _cachedTier = tier;
    return tier;
  }

  /// 激活邀请码（离线验证签名，成功后存储到本地并后台同步）
  Future<ActivationResult> activate(String code) async {
    final clientId = ClientIdService.clientId;
    if (clientId == null) {
      return ActivationResult(
        success: false,
        message: '客户端识别码未初始化',
        error: 'client_id_not_initialized',
      );
    }

    try {
      // 1. 本地验证签名（离线）
      final crypto = CryptoService(_configProvider);
      final payload = await crypto.verifyInviteCode(code);

      if (payload == null) {
        return ActivationResult(
          success: false,
          message: '邀请码无效或签名验证失败',
          error: 'invalid_signature',
        );
      }

      // 2. 检查邀请码是否过期
      final exp = payload['exp'] as int? ?? 0;
      if (exp > 0) {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (expiresAt.isBefore(DateTime.now())) {
          return ActivationResult(
            success: false,
            message: '邀请码已过期',
            error: 'code_expired',
          );
        }
      }

      // 3. 解析等级和到期时间
      final tier = payload['tier'] as String? ?? 'basic';
      final tierExpDays = payload['tier_exp'] as int? ?? 0;
      final codeId = payload['id'] as String?;

      if (codeId == null) {
        return ActivationResult(
          success: false,
          message: '邀请码格式错误',
          error: 'invalid_payload',
        );
      }

      DateTime? expiresAt;
      if (tierExpDays > 0) {
        expiresAt = DateTime.now().add(Duration(days: tierExpDays));
      }

      // 4. 保存到本地
      final activatedAt = DateTime.now();
      await _saveActivation(tier, expiresAt, codeId, activatedAt);

      // 5. 后台异步同步到服务器（不阻塞用户）
      _syncToBackendAsync(codeId, tier, activatedAt);

      return ActivationResult(
        success: true,
        tier: tier,
        expiresAt: expiresAt,
        message: '激活成功',
      );
    } catch (e) {
      await AppLogger.error('激活异常: $e', tag: 'ActivationService');
      return ActivationResult(
        success: false,
        message: '激活失败: $e',
        error: 'unknown_error',
      );
    }
  }

  /// 后台异步同步到服务器
  Future<void> _syncToBackendAsync(
    String codeId,
    String tier,
    DateTime activatedAt,
  ) async {
    // 不等待结果，后台静默同步
    unawaited(_syncToBackend(codeId, tier, activatedAt));
  }

  /// 同步到服务器
  Future<void> _syncToBackend(
    String codeId,
    String tier,
    DateTime activatedAt,
  ) async {
    try {
      final backendUrl = _configProvider.backendUrl;
      if (backendUrl.isEmpty) {
        await AppLogger.debug('后端地址未配置，跳过同步', tag: 'ActivationService');
        return;
      }

      final clientId = ClientIdService.clientId;
      if (clientId == null) {
        await AppLogger.debug('客户端ID未初始化，跳过同步', tag: 'ActivationService');
        return;
      }

      final dio = HttpClientFactory.create();
      final deviceInfo = _getDeviceInfo();

      await dio.post(
        '$backendUrl/api/invite/sync',
        data: {
          'code': codeId,
          'client_id': clientId,
          'device_info': deviceInfo,
          'tier': tier,
          'activated_at': activatedAt.toIso8601String(),
        },
      );

      await AppLogger.info('激活同步成功', tag: 'ActivationService');
    } on DioException catch (e) {
      await AppLogger.warning('激活同步失败: ${e.message}', tag: 'ActivationService');
      // 同步失败不影响本地激活状态
    } catch (e) {
      await AppLogger.error('激活同步异常: $e', tag: 'ActivationService');
    }
  }

  /// 升级等级（联网升级，成功后更新本地存储）
  Future<ActivationResult> upgrade(String code) async {
    final clientId = ClientIdService.clientId;
    if (clientId == null) {
      return ActivationResult(
        success: false,
        message: '客户端识别码未初始化',
        error: 'client_id_not_initialized',
      );
    }

    try {
      final backendUrl = _configProvider.backendUrl;
      if (backendUrl.isEmpty) {
        return ActivationResult(
          success: false,
          message: '后端服务地址未配置',
          error: 'backend_url_not_configured',
        );
      }

      final dio = HttpClientFactory.create();

      final response = await dio.post(
        '$backendUrl/api/invite/upgrade',
        data: {'code': code, 'client_id': clientId},
      );

      final result = ActivationResult.fromJson(response.data);

      if (result.success && result.tier != null) {
        // 升级时，需要从响应中获取 codeId，如果没有则使用现有的
        final existingCodeId = await getSavedInviteCode() ?? '';
        await _saveActivation(
          result.tier!,
          result.expiresAt,
          existingCodeId,
          DateTime.now(),
        );
      }

      return result;
    } on DioException catch (e) {
      debugPrint('[ActivationService] 升级请求失败: ${e.message}');
      return ActivationResult(
        success: false,
        message: '升级请求失败: ${e.message}',
        error: 'network_error',
      );
    } catch (e) {
      debugPrint('[ActivationService] 升级异常: $e');
      return ActivationResult(
        success: false,
        message: '升级失败: $e',
        error: 'unknown_error',
      );
    }
  }

  /// 查询激活状态（从服务器）
  Future<ActivationStatus?> queryStatus() async {
    final clientId = ClientIdService.clientId;
    if (clientId == null) {
      return null;
    }

    try {
      final backendUrl = _configProvider.backendUrl;
      if (backendUrl.isEmpty) {
        return null;
      }

      final dio = HttpClientFactory.create();

      final response = await dio.post(
        '$backendUrl/api/invite/status',
        data: {'client_id': clientId},
      );

      return ActivationStatus.fromJson(response.data);
    } catch (e) {
      debugPrint('[ActivationService] 查询状态失败: $e');
      return null;
    }
  }

  /// 检查是否有权限调用API（本地判断）
  bool canAccessApi(ApiType type) {
    final tier = getCurrentTier();

    switch (type) {
      case ApiType.config:
        // 配置同步：需要basic或plus
        return tier == UserTier.basic || tier == UserTier.plus;
      case ApiType.customAi:
        // 自定义AI：需要basic或plus
        return tier == UserTier.basic || tier == UserTier.plus;
      case ApiType.backendAi:
        // 后端AI服务：需要plus
        return tier == UserTier.plus;
    }
  }

  /// Plus用户：获取到期时间（本地存储）
  Future<DateTime?> getPlusExpiresAt() async {
    final expiresAtStr = await _storage.getPlusExpiresAt();
    if (expiresAtStr == null || expiresAtStr.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(expiresAtStr);
    } catch (e) {
      debugPrint('[ActivationService] 解析到期时间失败: $e');
      return null;
    }
  }

  /// 获取激活时间
  Future<DateTime?> getActivatedAt() async {
    final activatedAtStr = await _storage.getActivatedAt();
    if (activatedAtStr == null || activatedAtStr.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(activatedAtStr);
    } catch (e) {
      await AppLogger.warning('解析激活时间失败: $e', tag: 'ActivationService');
      return null;
    }
  }

  /// 获取保存的邀请码ID
  Future<String?> getSavedInviteCode() async {
    return await _storage.getInviteCode();
  }

  /// 清除缓存（用于重新加载）
  void clearCache() {
    _cachedTier = null;
  }

  // ==================== 私有方法 ====================

  UserTier _parseTier(String? tierStr) {
    switch (tierStr) {
      case 'basic':
        return UserTier.basic;
      case 'plus':
        return UserTier.plus;
      default:
        return UserTier.free;
    }
  }

  Future<void> _saveActivation(
    String tier,
    DateTime? expiresAt,
    String codeId,
    DateTime activatedAt,
  ) async {
    await _storage.setTier(tier);
    await _storage.setClientId(ClientIdService.clientId ?? '');
    await _storage.setInviteCode(codeId);
    await _storage.setActivatedAt(activatedAt.toIso8601String());

    if (expiresAt != null) {
      await _storage.setPlusExpiresAt(expiresAt.toIso8601String());
    } else {
      // 清除到期时间（永久激活）
      await _storage.setPlusExpiresAt('');
    }

    // 更新缓存
    _cachedTier = _parseTier(tier);

    await AppLogger.info(
      '激活状态已保存: tier=$tier, expiresAt=$expiresAt, codeId=$codeId',
      tag: 'ActivationService',
    );
  }

  /// 应用启动时验证（异步，不阻塞启动）
  Future<void> verifyOnStartup() async {
    final tier = await getCurrentTierAsync();
    if (tier == UserTier.free) {
      return;
    }

    final codeId = await _storage.getInviteCode();
    if (codeId == null || codeId.isEmpty) {
      await AppLogger.debug('未找到邀请码ID，跳过验证', tag: 'ActivationService');
      return;
    }

    try {
      final backendUrl = _configProvider.backendUrl;
      if (backendUrl.isEmpty) {
        await AppLogger.debug('后端地址未配置，跳过验证', tag: 'ActivationService');
        return;
      }

      final clientId = ClientIdService.clientId;
      if (clientId == null) {
        await AppLogger.debug('客户端ID未初始化，跳过验证', tag: 'ActivationService');
        return;
      }

      final dio = HttpClientFactory.create();

      // 设置超时时间（3秒）
      final response = await dio
          .post(
            '$backendUrl/api/invite/verify',
            data: {'client_id': clientId, 'code': codeId},
          )
          .timeout(const Duration(seconds: 3));

      final result = response.data as Map<String, dynamic>;
      final valid = result['valid'] as bool? ?? false;

      if (!valid) {
        // 激活已失效，清除本地状态
        await AppLogger.warning(
          '激活验证失败: ${result['message']}',
          tag: 'ActivationService',
        );
        await _clearActivation();
        // TODO: 通知UI更新（可以通过Provider或EventBus）
      } else {
        await AppLogger.info('激活验证通过', tag: 'ActivationService');
      }
    } on TimeoutException {
      // 超时，跳过验证，信任本地状态
      await AppLogger.debug('后端超时，跳过验证，信任本地状态', tag: 'ActivationService');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        // 网络不可用，跳过验证
        await AppLogger.debug('网络不可用，跳过验证，信任本地状态', tag: 'ActivationService');
      } else {
        await AppLogger.warning(
          '验证请求失败: ${e.message}',
          tag: 'ActivationService',
        );
      }
    } catch (e) {
      await AppLogger.error('验证异常: $e', tag: 'ActivationService');
    }
  }

  /// 清除激活状态
  Future<void> _clearActivation() async {
    await _storage.setTier('free');
    await _storage.setInviteCode('');
    await _storage.setPlusExpiresAt('');
    _cachedTier = UserTier.free;
    await AppLogger.info('激活状态已清除', tag: 'ActivationService');
  }

  Map<String, dynamic> _getDeviceInfo() {
    return {
      'platform': defaultTargetPlatform.name,
      'is_web': kIsWeb,
      'version': '1.0.0', // TODO: 从package_info获取
    };
  }
}
