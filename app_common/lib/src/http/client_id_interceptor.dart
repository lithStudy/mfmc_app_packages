import 'package:dio/dio.dart';

/// 客户端识别码拦截器
/// 在每个HTTP请求中自动添加 X-Client-ID 请求头
class ClientIdInterceptor extends Interceptor {
  ClientIdInterceptor(this._clientId);

  final String? _clientId;

  /// HTTP请求头名称
  static const String headerName = 'X-Client-ID';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 添加客户端识别码到请求头
    if (_clientId != null && _clientId!.isNotEmpty) {
      options.headers[headerName] = _clientId;
    }
    handler.next(options);
  }
}
