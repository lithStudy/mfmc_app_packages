import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';

/// 应用配置加载器
/// 根据构建模式（debug/release）加载不同的配置文件
class AppConfigLoader {
  AppConfigLoader();

  /// 缓存的配置
  AppConfig? _cachedConfig;

  /// 开发环境配置文件路径
  static const String _devConfigPath = 'assets/config/app_config_dev.json';

  /// 生产环境配置文件路径
  static const String _prodConfigPath = 'assets/config/app_config_prod.json';

  /// 加载应用配置
  /// 根据kDebugMode选择加载开发或生产配置
  /// 如果已有缓存则直接返回
  Future<AppConfig> load() async {
    if (_cachedConfig != null) {
      return _cachedConfig!;
    }

    // 根据构建模式选择配置文件
    final configPath = kDebugMode ? _devConfigPath : _prodConfigPath;

    try {
      final jsonString = await rootBundle.loadString(configPath);
      final configData = json.decode(jsonString) as Map<String, dynamic>;
      _cachedConfig = AppConfig.fromJson(configData);
      return _cachedConfig!;
    } catch (e) {
      print('[AppConfigLoader] 加载配置失败: $configPath, $e');
      // 如果加载失败，返回默认配置（空后端地址）
      _cachedConfig = AppConfig(backendUrl: '', invitePublicKey: '');
      return _cachedConfig!;
    }
  }

  /// 重新加载配置（清除缓存后重新加载）
  Future<AppConfig> reload() async {
    _cachedConfig = null;
    return load();
  }

  /// 清除缓存
  void clearCache() {
    _cachedConfig = null;
  }
}
