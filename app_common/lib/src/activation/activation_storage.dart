/// 激活信息存储接口
/// 各项目需要实现此接口以提供激活状态的持久化存储
abstract class ActivationStorage {
  /// 获取存储的等级
  Future<String?> getTier();

  /// 设置等级
  Future<void> setTier(String tier);

  /// 获取客户端ID
  Future<String?> getClientId();

  /// 设置客户端ID
  Future<void> setClientId(String clientId);

  /// 获取邀请码
  Future<String?> getInviteCode();

  /// 设置邀请码
  Future<void> setInviteCode(String code);

  /// 获取Plus到期时间
  Future<String?> getPlusExpiresAt();

  /// 设置Plus到期时间
  Future<void> setPlusExpiresAt(String? expiresAt);

  /// 获取激活时间
  Future<String?> getActivatedAt();

  /// 设置激活时间
  Future<void> setActivatedAt(String activatedAt);
}

/// 应用配置接口
/// 各项目需要实现此接口以提供应用配置
abstract class AppConfigProvider {
  /// 后端服务地址
  String get backendUrl;

  /// 邀请码公钥（Base64编码）
  String get invitePublicKey;
}
