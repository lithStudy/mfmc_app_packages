import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../http/http_client_factory.dart';
import '../util/json_utils.dart';
import 'ai_service.dart';

/// Google Gemini AI服务实现
/// 支持直连或通过后端路由转发
class GeminiAiService implements AiService {
  GeminiAiService({
    required this.apiKey,
    required this.backendUrl,
    this.model,
    this.visionModel,
    this.audioModel,
    Dio? dio,
  }) : _model = model ?? 'gemini-pro',
       _visionModel = visionModel ?? 'gemini-1.5-flash',
       _audioModel = audioModel ?? 'gemini-1.5-flash',
       _dio =
           dio ??
           HttpClientFactory.create(
             baseUrl: backendUrl,
             connectTimeout: const Duration(seconds: 10),
             receiveTimeout: const Duration(seconds: 30),
           );

  final String apiKey;

  /// 后端服务地址，非空时走后端路由转发，为空时直连AI API
  final String backendUrl;
  final String? model;
  final String? visionModel;
  final String? audioModel;
  final String _model;
  final String _visionModel;
  final String _audioModel;
  final Dio _dio;

  /// 调用Gemini API（根据配置决定是否通过后端路由转发）
  Future<Map<String, dynamic>> _callGemini(
    String prompt, {
    String? customModel,
    Map<String, dynamic>? customBody,
    Options? options,
  }) async {
    final modelToUse = customModel ?? _model;
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$modelToUse:generateContent?key=$apiKey';

    final headers = {'Content-Type': 'application/json'};
    final body =
        customBody ??
        {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 2000},
        };

    Response<Map<String, dynamic>> resp;
    if (backendUrl.isNotEmpty) {
      // 通过后端路由转发（Web端解决跨域）
      resp = await _dio.post<Map<String, dynamic>>(
        '/api/ai/proxy',
        data: {'url': url, 'method': 'POST', 'headers': headers, 'body': body},
        options: options,
      );
    } else {
      // 直连AI API（Android端）
      resp = await _dio.post<Map<String, dynamic>>(
        url,
        data: body,
        options: (options ?? Options()).copyWith(headers: headers),
      );
    }

    // 检查API返回的错误
    if (resp.data?['error'] != null) {
      final error = resp.data!['error'];
      final message =
          error['message']?.toString() ?? error['status']?.toString() ?? '未知错误';
      throw Exception('Gemini API错误：$message');
    }

    final candidates = resp.data?['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      // 检查是否有安全过滤器阻止
      final blockReason = resp.data?['candidates']?[0]?['finishReason'];
      if (blockReason != null && blockReason.toString().contains('SAFETY')) {
        throw Exception('内容被安全过滤器阻止，请调整输入内容');
      }
      // 检查是否有其他错误信息
      final errorMsg = resp.data?['error']?.toString() ?? '未知错误';
      throw Exception('Gemini API返回格式错误：缺少candidates。响应：$errorMsg');
    }

    final firstCandidate = candidates.first as Map<String, dynamic>?;
    if (firstCandidate == null) {
      throw Exception('Gemini API返回格式错误：candidates为空');
    }

    // 检查finishReason
    final finishReason = firstCandidate['finishReason']?.toString();
    if (finishReason != null && finishReason != 'STOP') {
      if (finishReason.contains('SAFETY')) {
        throw Exception('内容被安全过滤器阻止，请调整输入内容');
      }
      throw Exception('Gemini API生成未完成：$finishReason');
    }

    final content =
        firstCandidate['content']?['parts']?[0]?['text']?.toString() ?? '';
    if (content.isEmpty) {
      throw Exception('Gemini API返回内容为空');
    }

    return {'content': content, 'raw': resp.data};
  }

  @override
  Future<Map<String, dynamic>> generateText({
    required String prompt,
    Map<String, dynamic>? options,
  }) async {
    return await _callGemini(
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
    // 读取图片并转换为base64
    String base64Image;
    try {
      if (kIsWeb || imagePath.startsWith('data:') || !imagePath.contains('/')) {
        if (imagePath.startsWith('data:')) {
          final commaIndex = imagePath.indexOf(',');
          base64Image = commaIndex != -1
              ? imagePath.substring(commaIndex + 1)
              : imagePath;
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
      }

      if (base64Image.isEmpty) {
        throw Exception('图片数据为空');
      }

      final base64Length = base64Image.length;
      if (base64Length > 20 * 1024 * 1024) {
        throw Exception('图片太大，超过20MB限制');
      }
    } catch (e) {
      throw Exception('处理图片数据失败: $e');
    }

    // 使用Gemini的视觉模型
    final visionModelToUse = _visionModel;

    final visionBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inlineData': {'mimeType': 'image/jpeg', 'data': base64Image},
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 2000},
    };

    return await _callGemini(
      '',
      customModel: visionModelToUse,
      customBody: visionBody,
    );
  }

  @override
  Future<Map<String, dynamic>> extract({
    required String personId,
    required String prompt,
    required String inputHash,
  }) async {
    final response = await _callGemini(prompt);
    return _parseExtractResponse(response);
  }

  @override
  Future<Map<String, dynamic>> questions({
    required String personId,
    required String prompt,
    required String inputHash,
  }) async {
    final response = await _callGemini(prompt);
    return _parseQuestionsResponse(response);
  }

  @override
  Future<Map<String, dynamic>> summary({
    required String personId,
    required String prompt,
    required String inputHash,
  }) async {
    final response = await _callGemini(prompt);
    return _parseSummaryResponse(response);
  }

  @override
  Future<Map<String, dynamic>> generateTitle({
    required String prompt,
    required String inputHash,
  }) async {
    final response = await _callGemini(prompt);
    return _parseTitleResponse(response);
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

    // 如果只有一张图片，使用单图模式
    if (imagePaths.length == 1) {
      final response = await generateTextWithImage(
        prompt: prompt,
        imagePath: imagePaths.first,
      );
      return {'text': response['content'], 'raw': response['raw']};
    }

    // 多图模式：将多张图片放在同一个请求中
    final visionBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            // 添加所有图片
            for (final imagePath in imagePaths) ...[
              _createImagePart(imagePath),
            ],
          ],
        },
      ],
      'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 2000},
    };

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$_visionModel:generateContent?key=$apiKey';

    final headers = {'Content-Type': 'application/json'};
    final body = visionBody;

    Response<Map<String, dynamic>> resp;
    if (backendUrl.isNotEmpty) {
      // 通过后端路由转发
      resp = await _dio.post<Map<String, dynamic>>(
        '/api/ai/proxy',
        data: {'url': url, 'method': 'POST', 'headers': headers, 'body': body},
      );
    } else {
      // 直连AI API
      resp = await _dio.post<Map<String, dynamic>>(
        url,
        data: body,
        options: Options(headers: headers),
      );
    }

    // 检查API返回的错误
    if (resp.data?['error'] != null) {
      final error = resp.data!['error'];
      final message =
          error['message']?.toString() ?? error['status']?.toString() ?? '未知错误';
      throw Exception('Gemini API错误：$message');
    }

    final candidates = resp.data?['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini API返回格式错误：缺少candidates');
    }

    final firstCandidate = candidates.first as Map<String, dynamic>?;
    if (firstCandidate == null) {
      throw Exception('Gemini API返回格式错误：candidates为空');
    }

    final content =
        firstCandidate['content']?['parts']?[0]?['text']?.toString() ?? '';
    if (content.isEmpty) {
      throw Exception('Gemini API返回内容为空');
    }

    return {'text': content, 'raw': resp.data};
  }

  /// 创建图片部分的辅助方法
  Map<String, dynamic> _createImagePart(String imagePath) {
    String base64Image;
    try {
      if (kIsWeb || imagePath.startsWith('data:') || !imagePath.contains('/')) {
        if (imagePath.startsWith('data:')) {
          final commaIndex = imagePath.indexOf(',');
          base64Image = commaIndex != -1
              ? imagePath.substring(commaIndex + 1)
              : imagePath;
        } else {
          base64Image = imagePath;
        }
      } else {
        final imageFile = File(imagePath);
        if (!imageFile.existsSync()) {
          throw Exception('图片文件不存在：$imagePath');
        }
        final imageBytes = imageFile.readAsBytesSync();
        base64Image = base64Encode(imageBytes);
      }

      if (base64Image.isEmpty) {
        throw Exception('图片数据为空');
      }

      final base64Length = base64Image.length;
      if (base64Length > 20 * 1024 * 1024) {
        throw Exception('图片太大，超过20MB限制');
      }
    } catch (e) {
      throw Exception('处理图片数据失败: $e');
    }

    return {
      'inlineData': {'mimeType': 'image/jpeg', 'data': base64Image},
    };
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
    try {
      // 处理音频数据
      final audioBase64 = await _processAudio(audioPath);
      final mimeType = _getAudioMimeType(audioPath);

      debugPrint('[Gemini] ASR 音频MIME类型: $mimeType');

      // 构建音频转录请求体（使用多模态API）
      final transcriptionPrompt = prompt.isNotEmpty
          ? prompt
          : '请将以下音频内容准确转录为文字，保留原始语言，不要添加任何解释或总结。';

      final audioBody = {
        'contents': [
          {
            'parts': [
              {'text': transcriptionPrompt},
              {
                'inlineData': {'mimeType': mimeType, 'data': audioBase64},
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1, // 低温度以获得更准确的转录
          'maxOutputTokens': 8000,
        },
      };

      // 使用配置的语音模型
      final response = await _callGemini(
        '',
        customModel: _audioModel,
        customBody: audioBody,
      );

      final transcribedText = response['content']?.toString() ?? '';

      if (transcribedText.isEmpty) {
        throw Exception('Gemini语音识别返回内容为空');
      }

      return {
        'text': transcribedText,
        'content': transcribedText,
        'raw': response['raw'],
      };
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        throw Exception(
          'Gemini语音识别请求失败 [HTTP $statusCode]: ${responseData?.toString() ?? e.message}',
        );
      }
      rethrow;
    }
  }

  /// 处理音频数据，返回base64编码的字符串
  Future<String> _processAudio(String audioPath) async {
    String subAudioPath = audioPath.length > 100
        ? audioPath.substring(0, 100)
        : audioPath;
    debugPrint('[Gemini] audioPath: $subAudioPath');

    if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
      // URL格式，需要先下载
      final dio = Dio();
      final response = await dio.get<List<int>>(
        audioPath,
        options: Options(responseType: ResponseType.bytes),
      );
      return base64Encode(response.data!);
    } else if (audioPath.startsWith('data:')) {
      // data:audio/xxx;base64,xxx 格式
      final commaIndex = audioPath.indexOf(',');
      if (commaIndex == -1) {
        throw Exception('无效的data URI格式');
      }
      return audioPath.substring(commaIndex + 1);
    } else if (audioPath.startsWith('base64:')) {
      // base64:xxx 格式（来自AttachmentStorage）
      return audioPath.substring(7);
    } else if (kIsWeb || !audioPath.contains('/')) {
      // Web平台或其他情况，假设是纯base64字符串
      return audioPath;
    } else {
      // 本地文件路径
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('音频文件不存在：$audioPath');
      }
      final audioBytes = await audioFile.readAsBytes();

      // Gemini支持较大的音频文件（约8.4小时）
      if (audioBytes.length > 50 * 1024 * 1024) {
        throw Exception('音频文件太大，超过50MB限制');
      }

      return base64Encode(audioBytes);
    }
  }

  /// 根据文件扩展名或路径获取音频MIME类型
  String _getAudioMimeType(String path) {
    final lowerPath = path.toLowerCase();

    // 如果是data URI，从中提取MIME类型
    if (lowerPath.startsWith('data:')) {
      final mimeMatch = RegExp(r'data:([^;]+)').firstMatch(path);
      return mimeMatch?.group(1) ?? 'audio/mp4';
    }

    // 根据扩展名判断
    if (lowerPath.endsWith('.wav')) return 'audio/wav';
    if (lowerPath.endsWith('.mp3')) return 'audio/mpeg';
    if (lowerPath.endsWith('.aac')) return 'audio/aac';
    if (lowerPath.endsWith('.ogg')) return 'audio/ogg';
    if (lowerPath.endsWith('.flac')) return 'audio/flac';
    if (lowerPath.endsWith('.webm')) return 'audio/webm';
    if (lowerPath.endsWith('.m4a')) return 'audio/mp4';

    // 默认使用mp4
    return 'audio/mp4';
  }

  /// 解析提取响应（使用安全解析处理markdown代码块等情况）
  Map<String, dynamic> _parseExtractResponse(Map<String, dynamic> response) {
    final content = response['content']?.toString() ?? '';
    final json = parseJsonSafely(content);
    if (json is Map<String, dynamic>) {
      return json;
    }
    return {'text': content, 'raw': response};
  }

  /// 解析问题响应（使用安全解析处理markdown代码块等情况）
  Map<String, dynamic> _parseQuestionsResponse(Map<String, dynamic> response) {
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

  Map<String, dynamic> _parseTitleResponse(Map<String, dynamic> response) {
    final content = response['content']?.toString() ?? '';
    return {'title': content.trim(), 'raw': response};
  }

  Map<String, dynamic> _parseSummaryResponse(Map<String, dynamic> response) {
    final content = response['content']?.toString() ?? '';
    return {'summary': content, 'raw': response};
  }

  @override
  Stream<String> generateTextStream({
    required String systemPrompt,
    required String userContent,
    Map<String, dynamic>? options,
  }) async* {
    final combined =
        '${systemPrompt.trim()}\n\n---\n\n用户内容：\n${userContent.trim()}';
    final response = await generateText(prompt: combined, options: options);
    final content = response['content']?.toString() ?? '';
    if (content.isNotEmpty) yield content;
  }
}
