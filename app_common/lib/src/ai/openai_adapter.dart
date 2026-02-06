import 'package:dio/dio.dart';

import '../http/http_client_factory.dart';

/// OpenAI适配层
/// 提供统一的OpenAI格式调用方法
class OpenAiAdapter {
  OpenAiAdapter({required this.baseUrl, required this.apiKey, Dio? dio})
    : _dio =
          dio ??
          HttpClientFactory.create(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 120),
          );

  final String baseUrl;
  final String apiKey;
  final Dio _dio;

  /// 调用OpenAI chat completions接口
  Future<Map<String, dynamic>> chatCompletions({
    required List<Map<String, dynamic>> messages,
    String? model,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/chat/completions',
        data: {
          'messages': messages,
          if (model != null) 'model': model,
          'temperature': temperature,
          if (maxTokens != null) 'max_tokens': maxTokens,
        },
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      } else {
        final errorDetail = response.data?.toString() ?? '未知错误';
        throw Exception('API调用失败: ${response.statusCode}, 详情: $errorDetail');
      }
    } on DioException catch (e) {
      final errorDetail = e.response?.data?.toString() ?? e.message ?? '未知错误';
      throw Exception('网络请求失败: $errorDetail');
    }
  }

  /// 从OpenAI响应中提取文本内容
  static String extractContent(Map<String, dynamic> response) {
    try {
      final choices = response['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>?;
        if (message != null) {
          return message['content'] as String? ?? '';
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}
