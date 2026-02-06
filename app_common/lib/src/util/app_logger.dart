import 'package:flutter/foundation.dart';

import 'logger_service.dart';

/// 全局日志工具类，方便在应用中使用
class AppLogger {
  static LoggerService? _loggerService;
  static bool _initialized = false;

  /// 初始化日志服务（所有非Web平台）
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[AppLogger] 日志服务已初始化，跳过');
      return;
    }

    if (!kIsWeb) {
      debugPrint('[AppLogger] 开始初始化日志服务');
      try {
        _loggerService = await LoggerService.getInstance();
        _initialized = true;
        debugPrint('[AppLogger] 日志服务实例创建成功');
        await _loggerService!.info('日志服务初始化完成', tag: 'Logger');
        debugPrint('[AppLogger] 日志服务初始化完成');
      } catch (e, stackTrace) {
        debugPrint('[AppLogger] 日志服务初始化失败: $e');
        debugPrint('[AppLogger] 堆栈: $stackTrace');
      }
    } else {
      debugPrint('[AppLogger] Web平台，跳过日志服务初始化');
    }
  }

  /// 记录DEBUG级别日志
  static Future<void> debug(String message, {String? tag}) async {
    debugPrint(message);
    if (_loggerService != null) {
      await _loggerService!.debug(message, tag: tag);
    }
  }

  /// 记录INFO级别日志
  static Future<void> info(String message, {String? tag}) async {
    debugPrint(message);
    if (_loggerService != null) {
      await _loggerService!.info(message, tag: tag);
    }
  }

  /// 记录WARNING级别日志
  static Future<void> warning(String message, {String? tag}) async {
    debugPrint(message);
    if (_loggerService != null) {
      await _loggerService!.warning(message, tag: tag);
    }
  }

  /// 记录ERROR级别日志
  static Future<void> error(String message, {String? tag}) async {
    debugPrint(message);
    if (_loggerService != null) {
      await _loggerService!.error(message, tag: tag);
    }
  }
}
