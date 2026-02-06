/// 用户等级枚举
enum UserTier {
  free,
  basic,
  plus;

  String get displayName {
    switch (this) {
      case UserTier.free:
        return '免费用户';
      case UserTier.basic:
        return '基础用户';
      case UserTier.plus:
        return 'Plus用户';
    }
  }
}

/// API类型枚举
enum ApiType {
  config, // 配置同步
  customAi, // 自定义AI
  backendAi, // 后端AI服务
}

/// 激活结果
class ActivationResult {
  final bool success;
  final String? tier;
  final DateTime? expiresAt;
  final String message;
  final String? error;

  ActivationResult({
    required this.success,
    this.tier,
    this.expiresAt,
    required this.message,
    this.error,
  });

  factory ActivationResult.fromJson(Map<String, dynamic> json) {
    DateTime? expiresAt;
    if (json['expires_at'] != null) {
      try {
        expiresAt = DateTime.parse(json['expires_at']);
      } catch (e) {
        // ignore
      }
    }

    return ActivationResult(
      success: json['success'] ?? false,
      tier: json['tier'],
      expiresAt: expiresAt,
      message: json['message'] ?? '',
      error: json['error'],
    );
  }
}

/// 激活状态
class ActivationStatus {
  final bool activated;
  final UserTier tier;
  final DateTime? expiresAt;
  final int? daysRemaining;
  final bool canUpgrade;
  final DateTime? activatedAt;

  ActivationStatus({
    required this.activated,
    required this.tier,
    this.expiresAt,
    this.daysRemaining,
    required this.canUpgrade,
    this.activatedAt,
  });

  factory ActivationStatus.fromJson(Map<String, dynamic> json) {
    final tierStr = json['tier'] as String?;
    final tier = _parseTier(tierStr);

    DateTime? expiresAt;
    if (json['expires_at'] != null) {
      try {
        expiresAt = DateTime.parse(json['expires_at']);
      } catch (e) {
        // ignore
      }
    }

    DateTime? activatedAt;
    if (json['activated_at'] != null) {
      try {
        activatedAt = DateTime.parse(json['activated_at']);
      } catch (e) {
        // ignore
      }
    }

    return ActivationStatus(
      activated: json['activated'] ?? false,
      tier: tier,
      expiresAt: expiresAt,
      daysRemaining: json['days_remaining'],
      canUpgrade: json['can_upgrade'] ?? true,
      activatedAt: activatedAt,
    );
  }

  static UserTier _parseTier(String? tierStr) {
    switch (tierStr) {
      case 'basic':
        return UserTier.basic;
      case 'plus':
        return UserTier.plus;
      default:
        return UserTier.free;
    }
  }
}
