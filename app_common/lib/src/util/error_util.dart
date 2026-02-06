import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 将异常转换为用户友好的错误消息
String formatErrorForUser(dynamic error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '网络请求超时，请检查网络连接';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          if (statusCode >= 500) {
            return '服务器错误，请稍后重试';
          } else if (statusCode == 401) {
            return '认证失败，请检查API Key是否正确';
          } else if (statusCode == 403) {
            // 在Web环境下，403通常是CORS问题
            if (kIsWeb) {
              return 'Web环境下直接调用AI服务被浏览器阻止（CORS限制），请使用代理服务或切换到移动端';
            }
            return '没有权限访问，请检查API Key和权限设置';
          } else if (statusCode == 404) {
            return '请求的资源不存在，请检查API端点配置';
          } else {
            return '请求失败（错误码：$statusCode）';
          }
        }
        return '服务器响应错误';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.connectionError:
        // 检查是否是localhost连接错误
        final message = error.message?.toLowerCase() ?? '';
        if (message.contains('localhost') || message.contains('127.0.0.1')) {
          return '无法连接到AI服务，请检查设置中的代理地址配置';
        }
        // 检查是否是DNS解析失败
        if (message.contains('host lookup') ||
            message.contains('failed host lookup') ||
            message.contains('name resolution')) {
          return 'DNS解析失败，无法访问AI服务。请检查：\n1. 设备网络连接是否正常\n2. 如果是模拟器，请检查模拟器网络设置\n3. 尝试重启设备或模拟器';
        }
        // 在Web环境下，连接错误可能是CORS问题
        if (kIsWeb &&
            (message.contains('cors') || message.contains('cross-origin'))) {
          return 'Web环境下存在跨域限制，请使用代理服务或切换到移动端';
        }
        return '网络连接失败，请检查网络设置';
      case DioExceptionType.badCertificate:
        return '证书验证失败';
      case DioExceptionType.unknown:
        final message = error.message?.toLowerCase() ?? '';
        if (message.contains('xmlhttprequest') ||
            message.contains('connection error')) {
          if (message.contains('localhost') || message.contains('127.0.0.1')) {
            return '无法连接到AI服务，请检查设置中的代理地址配置';
          }
          // 检查是否是CORS相关错误
          if (kIsWeb &&
              (message.contains('cors') ||
                  message.contains('cross-origin') ||
                  message.contains('403'))) {
            return 'Web环境下存在跨域限制，请使用代理服务或切换到移动端';
          }
          return '网络连接错误，请检查网络设置';
        }
        // 检查错误信息中是否包含403或CORS相关
        if (kIsWeb &&
            (message.contains('403') || message.contains('forbidden'))) {
          return 'Web环境下直接调用AI服务被阻止，请使用代理服务或切换到移动端';
        }
        return '未知错误：${error.message ?? '网络请求失败'}';
    }
  }

  // 处理其他类型的异常
  final errorStr = error.toString().toLowerCase();
  if (errorStr.contains('connection') && errorStr.contains('error')) {
    if (errorStr.contains('localhost') || errorStr.contains('127.0.0.1')) {
      return '无法连接到AI服务，请检查设置中的代理地址配置';
    }
    return '网络连接错误，请检查网络设置';
  }

  // 默认返回简化的错误信息（去掉技术细节）
  final msg = error.toString();

  // 提取关键错误信息
  String extractKeyMessage(String message) {
    // 提取常见错误关键词
    if (message.contains('localhost') || message.contains('127.0.0.1')) {
      return '无法连接到AI代理服务（localhost:8033），请确保后端代理服务已启动';
    }
    if (message.contains('Connection refused') || message.contains('连接被拒绝')) {
      return '无法连接到AI服务，请检查代理服务是否运行';
    }
    if (message.contains('timeout') || message.contains('超时')) {
      return '请求超时，请检查网络连接';
    }
    if (message.contains('CORS') || message.contains('跨域')) {
      return 'Web环境下存在跨域限制，请使用代理服务';
    }
    if (message.contains('401') || message.contains('Unauthorized')) {
      return '认证失败，请检查API Key配置';
    }
    if (message.contains('403') || message.contains('Forbidden')) {
      return '访问被拒绝，请检查API Key权限';
    }
    if (message.contains('404') || message.contains('Not Found')) {
      return '请求的资源不存在，请检查API端点配置';
    }
    if (message.contains('500') || message.contains('Internal Server Error')) {
      return '服务器内部错误，请稍后重试';
    }

    // 如果错误信息太长，提取前100个字符
    if (msg.length > 100) {
      final shortMsg = msg.substring(0, 100);
      // 尝试提取最后一个句号之前的内容
      final lastPeriod = shortMsg.lastIndexOf('.');
      if (lastPeriod > 20) {
        return shortMsg.substring(0, lastPeriod + 1);
      }
      return '$shortMsg...';
    }

    return msg;
  }

  return extractKeyMessage(msg);
}
