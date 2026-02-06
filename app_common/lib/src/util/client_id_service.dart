import 'package:uuid/uuid.dart';

/// 客户端ID存储接口
/// 各项目需要实现此接口以提供客户端ID的持久化存储
abstract class ClientIdStorage {
  /// 获取存储的客户端ID
  Future<String?> getClientId();

  /// 存储客户端ID
  Future<void> setClientId(String clientId);
}

/// 客户端识别码服务
/// 用于生成和管理客户端唯一识别码，便于后端日志追踪
class ClientIdService {
  /// 缓存的客户端ID
  static String? _cachedClientId;

  /// 确保客户端识别码存在
  /// 如果不存在则生成新的UUID并存储
  /// 返回客户端识别码
  static Future<String> ensureClientId(ClientIdStorage storage) async {
    // 如果已缓存，直接返回
    if (_cachedClientId != null) {
      return _cachedClientId!;
    }

    // 尝试从存储读取
    final existingId = await storage.getClientId();
    if (existingId != null && existingId.isNotEmpty) {
      _cachedClientId = existingId;
      return existingId;
    }

    // 生成新的UUID
    const uuid = Uuid();
    final newClientId = uuid.v4();

    // 存储
    await storage.setClientId(newClientId);
    _cachedClientId = newClientId;

    return newClientId;
  }

  /// 获取缓存的客户端识别码
  /// 如果未初始化则返回null
  static String? get clientId => _cachedClientId;

  /// 设置客户端ID（用于从外部初始化）
  static void setClientIdFromExternal(String clientId) {
    _cachedClientId = clientId;
  }

  /// 清除缓存（仅用于测试）
  static void clearCache() {
    _cachedClientId = null;
  }
}
