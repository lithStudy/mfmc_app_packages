import '../activation/activation_storage.dart';

/// 应用配置数据模型
class AppConfig implements AppConfigProvider {
  /// 后端服务地址（统一地址，用于AI代理、路由转发、配置同步等）
  @override
  final String backendUrl;

  /// 邀请码验证公钥（Ed25519 Base64编码）
  @override
  final String invitePublicKey;

  AppConfig({required this.backendUrl, required this.invitePublicKey});

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      backendUrl: json['backendUrl'] as String? ?? '',
      invitePublicKey: json['invitePublicKey'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'backendUrl': backendUrl, 'invitePublicKey': invitePublicKey};
  }
}
