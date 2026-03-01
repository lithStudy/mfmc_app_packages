import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../http/http_client_factory.dart';
import '../util/json_utils.dart';
import 'ai_service.dart';

/// OpenAI兼容API的抽象基类
/// 适用于智普AI、豆包等使用OpenAI兼容格式的服务
abstract class OpenAiCompatibleAiService implements AiService {
  OpenAiCompatibleAiService({
    required this.apiKey,
    required this.backendUrl,
    String? endpoint,
    String? model,
    String? visionModel,
    String? audioModel,
    Dio? dio,
  }) : _endpoint = endpoint,
       _model = model,
       _visionModel = visionModel,
       _audioModel = audioModel,
       _dio = dio ?? _createDio(backendUrl);

  static Dio _createDio(String backendUrl) {
    final dio = HttpClientFactory.create(
      baseUrl: backendUrl.isNotEmpty ? backendUrl : '',
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 180),
      headers: {'User-Agent': 'AppCommon/1.0.0'},
    );
    dio.options.validateStatus = (status) => status != null && status < 500;
    return dio;
  }

  final String apiKey;

  /// 后端服务地址，非空时走后端路由转发，为空时直连AI API
  final String backendUrl;
  final String? _endpoint;
  final String? _model;
  final String? _visionModel;
  final String? _audioModel;
  final Dio _dio;

  /// 服务名称，用于日志和错误信息
  String get serviceName;

  /// 默认API端点
  String get defaultEndpoint;

  /// 默认文本模型
  String get defaultModel;

  /// 默认视觉模型
  String get defaultVisionModel;

  /// 默认语音模型
  String get defaultAudioModel;

  /// 获取实际使用的端点
  String get endpoint => _endpoint ?? defaultEndpoint;

  /// 获取实际使用的模型
  String get model => _model ?? defaultModel;

  /// 获取实际使用的视觉模型
  String get visionModel => _visionModel ?? defaultVisionModel;

  /// 获取实际使用的语音模型
  String get audioModel => _audioModel ?? defaultAudioModel;

  /// 调用API（根据配置决定是否通过代理）
  @protected
  Future<Map<String, dynamic>> callApi(
    String prompt, {
    String? customEndpoint,
    Map<String, dynamic>? customBody,
    Options? options,
  }) async {
    final targetUrl = customEndpoint ?? endpoint;
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    final body =
        customBody ??
        {
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        };

    Response<Map<String, dynamic>> resp;
    try {
      debugPrint(
        '[$serviceName] backendUrl: "$backendUrl" (isEmpty: ${backendUrl.isEmpty})',
      );
      debugPrint('[$serviceName] _dio.baseUrl: "${_dio.options.baseUrl}"');
      debugPrint('[$serviceName] targetUrl: $targetUrl');

      if (backendUrl.isNotEmpty) {
        // 通过后端路由转发（Web端解决跨域）
        if (_dio.options.baseUrl != backendUrl) {
          debugPrint(
            '[$serviceName] 更新 baseUrl: "${_dio.options.baseUrl}" -> "$backendUrl"',
          );
          _dio.options.baseUrl = backendUrl;
        }
        final fullUrl = '$backendUrl/api/ai/proxy';
        debugPrint('[$serviceName] 使用后端转发，完整URL: $fullUrl');
        resp = await _dio.post<Map<String, dynamic>>(
          '/api/ai/proxy',
          data: {
            'url': targetUrl,
            'method': 'POST',
            'headers': headers,
            'body': body,
          },
          options: options,
        );
      } else {
        // 直连AI API（Android端）
        debugPrint('[$serviceName] 直连AI API（backendUrl为空）');
        resp = await _dio.post<Map<String, dynamic>>(
          targetUrl,
          data: body,
          options: (options ?? Options()).copyWith(
            headers: headers,
            followRedirects: true,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
      }
    } on DioException catch (e) {
      debugPrint('[$serviceName] 请求失败: ${e.type}');
      debugPrint('[$serviceName] backendUrl: "$backendUrl"');
      debugPrint('[$serviceName] _dio.baseUrl: "${_dio.options.baseUrl}"');
      debugPrint('[$serviceName] targetUrl: $targetUrl');
      debugPrint('[$serviceName] 错误信息: ${e.message}');
      debugPrint('[$serviceName] 响应状态: ${e.response?.statusCode}');
      debugPrint('[$serviceName] 响应数据: ${e.response?.data}');
      rethrow;
    }

    // 检查错误响应
    if (resp.data?['error'] != null) {
      final error = resp.data?['error'];
      final message =
          error['message']?.toString() ?? error['code']?.toString() ?? '未知错误';
      throw Exception('${serviceName}API错误：$message');
    }

    // 提取响应内容
    final choices = resp.data?['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      final errorMsg = resp.data?['error']?.toString() ?? '未知错误';
      throw Exception('${serviceName}API返回格式错误：缺少choices字段。响应：$errorMsg');
    }

    final firstChoice = choices.first as Map?;
    if (firstChoice == null) {
      throw Exception('${serviceName}API返回格式错误：choices为空');
    }

    final message = firstChoice['message'] as Map?;
    if (message == null) {
      throw Exception('${serviceName}API返回格式错误：缺少message字段');
    }

    final content = message['content']?.toString() ?? '';
    if (content.isEmpty) {
      throw Exception('${serviceName}API返回内容为空');
    }

    return {'content': content, 'raw': resp.data};
  }

  /// 处理图片，返回 (base64Image, mimeType)
  @protected
  Future<(String, String)> processImage(String imagePath) async {
    String base64Image;
    String imageMimeType = 'image/jpeg';

    if (kIsWeb ||
        imagePath.startsWith('data:') ||
        (!imagePath.contains('/') && !imagePath.contains('\\'))) {
      if (imagePath.startsWith('data:')) {
        final commaIndex = imagePath.indexOf(',');
        if (commaIndex != -1) {
          final header = imagePath.substring(0, commaIndex);
          base64Image = imagePath.substring(commaIndex + 1);
          final mimeMatch = RegExp(r'data:([^;]+)').firstMatch(header);
          if (mimeMatch != null) {
            imageMimeType = mimeMatch.group(1) ?? 'image/jpeg';
          }
        } else {
          base64Image = imagePath;
        }
      } else if (imagePath.startsWith('base64:')) {
        base64Image = imagePath.substring(7);
      } else {
        base64Image = imagePath;
      }
    } else {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('图片文件不存在：$imagePath');
      }
      final imageBytes = await imageFile.readAsBytes();
      base64Image = base64Encode(imageBytes);

      if (imagePath.toLowerCase().endsWith('.png')) {
        imageMimeType = 'image/png';
      } else if (imagePath.toLowerCase().endsWith('.gif')) {
        imageMimeType = 'image/gif';
      } else if (imagePath.toLowerCase().endsWith('.webp')) {
        imageMimeType = 'image/webp';
      }
    }

    if (base64Image.isEmpty) {
      throw Exception('图片数据为空');
    }

    final base64Length = base64Image.length;
    if (base64Length > 20 * 1024 * 1024) {
      throw Exception('图片太大，超过20MB限制');
    }

    return (base64Image, imageMimeType);
  }

  /// 解析提取响应（使用安全解析处理markdown代码块等情况）
  @protected
  Map<String, dynamic> parseExtractResponse(Map<String, dynamic> response) {
    final content = response['content']?.toString() ?? '';
    final json = parseJsonSafely(content);
    if (json is Map<String, dynamic>) {
      return json;
    }
    return {'text': content, 'raw': response};
  }

  /// 解析问题响应（使用安全解析处理markdown代码块等情况）
  @protected
  Map<String, dynamic> parseQuestionsResponse(Map<String, dynamic> response) {
    final content = response['content']?.toString() ?? '';
    final json = parseJsonSafely(content);
    if (json is List) {
      return {'questions': json};
    } else if (json is Map && json['questions'] is List) {
      return json as Map<String, dynamic>;
    } else if (json is Map && json['items'] is List) {
      return {'questions': json['items']};
    }
    return {
      'questions': [
        {'text': '能补充一下症状持续了多久吗？'},
        {'text': '还有其他不适症状吗？'},
        {'text': '症状的严重程度如何？'},
      ],
    };
  }

  /// 解析标题响应
  @protected
  Map<String, dynamic> parseTitleResponse(Map<String, dynamic> response) {
    final content = response['content']?.toString() ?? '';
    return {'title': content.trim(), 'raw': response};
  }

  /// 解析摘要响应
  @protected
  Map<String, dynamic> parseSummaryResponse(Map<String, dynamic> response) {
    final content = response['content']?.toString() ?? '';
    return {'summary': content, 'raw': response};
  }

  // ============ AiService 接口实现 ============

  @override
  Future<Map<String, dynamic>> generateText({
    required String prompt,
    Map<String, dynamic>? options,
  }) async {
    return await callApi(
      prompt,
      options: options != null ? Options(extra: options) : null,
    );
  }

  @override
  Future<Map<String, dynamic>> generateTextWithImage({
    required String prompt,
    required String imagePath,
    Map<String, dynamic>? options,
  }) async {
    try {
      final (base64Image, imageMimeType) = await processImage(imagePath);

      // OpenAI兼容格式的视觉请求
      final imageUrl = 'data:$imageMimeType;base64,$base64Image';
      final visionBody = {
        'model': visionModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': imageUrl},
              },
              {'type': 'text', 'text': prompt},
            ],
          },
        ],
        'temperature': 0.4,
        'max_tokens': 2000,
      };

      return await callApi(
        '',
        customBody: visionBody,
        options: options != null ? Options(extra: options) : null,
      );
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        throw Exception(
          '$serviceName视觉识别请求失败 [HTTP $statusCode]: ${responseData?.toString() ?? e.message}',
        );
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> extract({
    required String personId,
    required String prompt,
    required String inputHash,
  }) async {
    final response = await callApi(prompt);
    return parseExtractResponse(response);
  }

  @override
  Future<Map<String, dynamic>> questions({
    required String personId,
    required String prompt,
    required String inputHash,
  }) async {
    final response = await callApi(prompt);
    return parseQuestionsResponse(response);
  }

  @override
  Future<Map<String, dynamic>> summary({
    required String personId,
    required String prompt,
    required String inputHash,
  }) async {
    final response = await callApi(prompt);
    return parseSummaryResponse(response);
  }

  @override
  Future<Map<String, dynamic>> generateTitle({
    required String prompt,
    required String inputHash,
  }) async {
    final response = await callApi(prompt);
    return parseTitleResponse(response);
  }

  @override
  Future<Map<String, dynamic>> visionRecognize({
    required String personId,
    required String prompt,
    required List<String> imagePaths,
    required String inputHash,
  }) async {
    if (imagePaths.isEmpty) {
      throw Exception('没有提供图片路径');
    }

    // 目前先处理第一张图片
    final response = await generateTextWithImage(
      prompt: prompt,
      imagePath: imagePaths.first,
    );
    return {'text': response['content'], 'raw': response['raw']};
  }

  @override
  Future<Map<String, dynamic>> examinationOcr({
    required String personId,
    required String prompt,
    required String imagePath,
    required String inputHash,
  }) async {
    final response = await generateTextWithImage(
      prompt: prompt,
      imagePath: imagePath,
    );
    return {'text': response['content'], 'raw': response['raw']};
  }

  @override
  Future<Map<String, dynamic>> labTestOcr({
    required String personId,
    required String prompt,
    required String imagePath,
    required String inputHash,
  }) async {
    final response = await generateTextWithImage(
      prompt: prompt,
      imagePath: imagePath,
    );
    return {'text': response['content'], 'raw': response['raw']};
  }

  @override
  Future<Map<String, dynamic>> audioTranscription({
    required String personId,
    required String prompt,
    required String audioPath,
    required String inputHash,
  }) async {
    // 默认不支持音频转录，子类可以覆盖实现
    throw UnimplementedError('$serviceName音频转录功能暂未实现');
  }

  @override
  Stream<String> generateTextStream({
    required String systemPrompt,
    required String userContent,
    Map<String, dynamic>? options,
  }) async* {
    if (backendUrl.isNotEmpty) {
      // 后端代理暂不支持 SSE 流式，退化为一次请求后整体 yield
      final body = {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
        'temperature': 0.7,
        'max_tokens': 2000,
      };
      final result = await callApi(
        '',
        customBody: body,
        options: options != null ? Options(extra: options) : null,
      );
      final content = result['content']?.toString() ?? '';
      if (content.isNotEmpty) yield content;
      return;
    }

    final targetUrl = endpoint;
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    final body = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContent},
      ],
      'stream': true,
      'temperature': 0.7,
      'max_tokens': 2000,
    };

    final resp = await _dio.post<ResponseBody>(
      targetUrl,
      data: body,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        receiveTimeout: const Duration(seconds: 180),
      ),
    );

    if (resp.data == null) return;

    final stream = resp.data!.stream;
    var buffer = '';
    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();
      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ') || trimmed == 'data: [DONE]') {
          continue;
        }
        final jsonStr = trimmed.substring(6);
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>?;
          final choices = json?['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final first = choices.first as Map?;
          final delta = first?['delta'] as Map?;
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) yield content;
        } catch (_) {
          // 忽略单行解析错误
        }
      }
    }
    if (buffer.trim().isNotEmpty) {
      final trimmed = buffer.trim();
      if (trimmed.startsWith('data: ') && trimmed != 'data: [DONE]') {
        try {
          final json = jsonDecode(trimmed.substring(6)) as Map<String, dynamic>?;
          final choices = json?['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final first = choices.first as Map?;
            final delta = first?['delta'] as Map?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) yield content;
          }
        } catch (_) {}
      }
    }
  }
}
