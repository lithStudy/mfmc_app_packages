import 'package:dio/dio.dart';

import '../util/client_id_service.dart';
import 'client_id_interceptor.dart';

/// 统一HTTP客户端工厂
/// 集中管理所有Dio实例的创建和配置
class HttpClientFactory {
  /// 缓存的客户端识别码
  static String? _clientId;

  /// 是否已初始化
  static bool _initialized = false;

  /// 初始化工厂（应用启动时调用一次）
  /// 必须在使用 create() 之前调用
  static Future<void> initialize(ClientIdStorage storage) async {
    if (_initialized) return;

    _clientId = await ClientIdService.ensureClientId(storage);
    _initialized = true;
  }

  /// 使用已有的客户端ID初始化（不需要存储）
  static void initializeWithClientId(String clientId) {
    if (_initialized) return;

    _clientId = clientId;
    ClientIdService.setClientIdFromExternal(clientId);
    _initialized = true;
  }

  /// 获取客户端识别码
  static String? get clientId => _clientId;

  /// 创建配置好的Dio实例
  /// 自动添加客户端识别码拦截器
  ///
  /// [baseUrl] 基础URL，可选
  /// [connectTimeout] 连接超时时间，默认30秒
  /// [receiveTimeout] 接收超时时间，默认120秒
  static Dio create({
    String? baseUrl,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 120),
    Map<String, dynamic>? headers,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {'Content-Type': 'application/json', ...?headers},
      ),
    );

    // 添加客户端识别码拦截器
    dio.interceptors.add(ClientIdInterceptor(_clientId));

    return dio;
  }

  /// 重置工厂状态（仅用于测试）
  static void reset() {
    _clientId = null;
    _initialized = false;
  }
}
