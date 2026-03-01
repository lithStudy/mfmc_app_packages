import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../util/json_utils.dart';
import 'ai_service.dart';
import 'openai_adapter.dart';

/// 后端AI服务实现
/// 调用后端的OpenAI兼容接口
class BackendAiService implements AiService {
  BackendAiService({required this.backendUrl, this.visionModel, Dio? dio})
    : _adapter = OpenAiAdapter(
        baseUrl: '$backendUrl/api/ai',
        apiKey: 'dummy', // 后端转发服务不需要真实的API Key
        dio: dio,
      );

  final String backendUrl;
  final String? visionModel;
  final OpenAiAdapter _adapter;

  /// 调用OpenAI chat接口
  Future<Map<String, dynamic>> _callChat({
    required List<Map<String, dynamic>> messages,
    String? model,
    double temperature = 0.7,
  }) async {
    final response = await _adapter.chatCompletions(
      messages: messages,
      model: model,
      temperature: temperature,
    );

    // 提取文本内容
    final content = OpenAiAdapter.extractContent(response);

    return {'text': content, 'content': content, 'raw': response};
  }

  @override
  Future<Map<String, dynamic>> generateText({
    required String prompt,
    Map<String, dynamic>? options,
  }) async {
    final messages = [
      {'role': 'user', 'content': prompt},
    ];

    return await _callChat(
      messages: messages,
      temperature: options?['temperature'] as double? ?? 0.7,
    );
  }

  @override
  Future<Map<String, dynamic>> generateTextWithImage({
    required String prompt,
    required String imagePath,
    Map<String, dynamic>? options,
  }) async {
    // TODO: 实现图片支持
    throw UnimplementedError('图片支持待实现');
  }

  @override
  Future<Map<String, dynamic>> extract({
    required String personId,
    required String prompt,
    required String inputHash,
  }) async {
    final messages = [
      {'role': 'user', 'content': prompt},
    ];

    return await _callChat(messages: messages);
  }

  @override
  Future<Map<String, dynamic>> questions({
    required String personId,
    required String prompt,
    required String inputHash,
  }) async {
    final messages = [
      {'role': 'user', 'content': prompt},
    ];

    final response = await _callChat(messages: messages);

    // 解析AI返回的JSON字符串数组或对象数组（使用安全解析处理markdown代码块等情况）
    final content = response['content']?.toString() ?? '';
    final json = parseJsonSafely(content);
    if (json != null) {
      if (json is List) {
        // 如果是数组，转换为对象数组格式
        final questions = json.map((item) {
          if (item is String) {
            // 字符串数组：转换为带空选项的对象（UI会显示文本输入框）
            return {'text': item, 'options': []};
          } else if (item is Map) {
            // 已经是对象格式，确保有text、options和isMultiple字段
            final question = Map<String, dynamic>.from(item);
            if (!question.containsKey('text')) {
              question['text'] = question['question'] ?? item.toString();
            }
            if (!question.containsKey('options')) {
              question['options'] = [];
            }
            // 保留isMultiple字段，如果没有则默认为false（单选）
            if (!question.containsKey('isMultiple') &&
                !question.containsKey('is_multiple')) {
              question['isMultiple'] = false;
            } else if (question.containsKey('is_multiple') &&
                !question.containsKey('isMultiple')) {
              question['isMultiple'] = question['is_multiple'];
            }
            return question;
          } else {
            return {'text': item.toString(), 'options': []};
          }
        }).toList();
        return {'questions': questions, 'raw': response};
      } else if (json is Map && json['questions'] is List) {
        // 确保questions数组中的每个元素都有正确的格式
        final questions = (json['questions'] as List).map((item) {
          if (item is String) {
            return {'text': item, 'options': []};
          } else if (item is Map) {
            final question = Map<String, dynamic>.from(item);
            if (!question.containsKey('text')) {
              question['text'] = question['question'] ?? item.toString();
            }
            if (!question.containsKey('options')) {
              question['options'] = [];
            }
            // 保留isMultiple字段，如果没有则默认为false（单选）
            if (!question.containsKey('isMultiple') &&
                !question.containsKey('is_multiple')) {
              question['isMultiple'] = false;
            } else if (question.containsKey('is_multiple') &&
                !question.containsKey('isMultiple')) {
              question['isMultiple'] = question['is_multiple'];
            }
            return question;
          } else {
            return {'text': item.toString(), 'options': []};
          }
        }).toList();
        return {'questions': questions, 'raw': response};
      } else if (json is Map && json['items'] is List) {
        // 处理items字段
        final questions = (json['items'] as List).map((item) {
          if (item is String) {
            return {'text': item, 'options': []};
          } else if (item is Map) {
            final question = Map<String, dynamic>.from(item);
            if (!question.containsKey('text')) {
              question['text'] = question['question'] ?? item.toString();
            }
            if (!question.containsKey('options')) {
              question['options'] = [];
            }
            // 保留isMultiple字段，如果没有则默认为false（单选）
            if (!question.containsKey('isMultiple') &&
                !question.containsKey('is_multiple')) {
              question['isMultiple'] = false;
            } else if (question.containsKey('is_multiple') &&
                !question.containsKey('isMultiple')) {
              question['isMultiple'] = question['is_multiple'];
            }
            return question;
          } else {
            return {'text': item.toString(), 'options': []};
          }
        }).toList();
        return {'questions': questions, 'raw': response};
      }
    }

    // 如果解析失败或格式不匹配，返回原始响应（parseCandidates会处理）
    return response;
  }

  @override
  Future<Map<String, dynamic>> summary({
    required String personId,
    required String prompt,
    required String inputHash,
  }) async {
    final messages = [
      {'role': 'user', 'content': prompt},
    ];

    return await _callChat(messages: messages);
  }

  @override
  Future<Map<String, dynamic>> visionRecognize({
    required String personId,
    required String prompt,
    required List<String> imagePaths,
    required String inputHash,
  }) async {
    // 处理所有图片，转换为 base64
    final imageContents = <Map<String, dynamic>>[];

    for (final imagePath in imagePaths) {
      String base64Image;
      String mimeType = 'image/jpeg'; // 默认 MIME 类型

      try {
        // 处理不同的图片路径格式
        if (kIsWeb ||
            imagePath.startsWith('base64:') ||
            !imagePath.contains('/')) {
          // Web 平台或已经是 base64 数据
          if (imagePath.startsWith('base64:')) {
            base64Image = imagePath.substring(7); // 去掉 "base64:" 前缀
          } else if (imagePath.startsWith('data:')) {
            // data:image/jpeg;base64,... 格式
            final commaIndex = imagePath.indexOf(',');
            if (commaIndex != -1) {
              final header = imagePath.substring(0, commaIndex);
              base64Image = imagePath.substring(commaIndex + 1);
              // 尝试从 header 中提取 MIME 类型
              final mimeMatch = RegExp(r'data:([^;]+)').firstMatch(header);
              if (mimeMatch != null) {
                mimeType = mimeMatch.group(1) ?? 'image/jpeg';
              }
            } else {
              base64Image = imagePath;
            }
          } else {
            // 纯 base64 字符串
            base64Image = imagePath;
          }
        } else {
          // 移动平台：从文件读取
          final imageFile = File(imagePath);
          if (!await imageFile.exists()) {
            throw Exception('图片文件不存在：$imagePath');
          }
          final imageBytes = await imageFile.readAsBytes();
          base64Image = base64Encode(imageBytes);

          // 根据文件扩展名判断 MIME 类型
          if (imagePath.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
          } else if (imagePath.toLowerCase().endsWith('.gif')) {
            mimeType = 'image/gif';
          } else if (imagePath.toLowerCase().endsWith('.webp')) {
            mimeType = 'image/webp';
          }
        }

        if (base64Image.isEmpty) {
          throw Exception('图片数据为空');
        }

        // 检查图片大小（OpenAI 限制 20MB）
        final base64Length = base64Image.length;
        if (base64Length > 20 * 1024 * 1024) {
          throw Exception('图片太大，超过20MB限制');
        }

        // 添加到图片内容列表
        imageContents.add({
          'type': 'image_url',
          'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
        });
      } catch (e) {
        throw Exception('处理图片失败 ($imagePath): $e');
      }
    }

    // 构建 OpenAI vision API 格式的消息
    // content 是一个数组，包含文本和图片对象
    final content = <dynamic>[
      {'type': 'text', 'text': prompt},
      ...imageContents,
    ];

    final messages = [
      {'role': 'user', 'content': content},
    ];

    // Plus模式：不传递模型名称，让后端根据环境变量配置自动选择
    // 后端会检测到视觉请求并自动使用 AI_VISION_MODEL 环境变量配置的模型
    return await _callChat(messages: messages, model: null, temperature: 0.7);
  }

  @override
  Future<Map<String, dynamic>> generateTitle({
    required String prompt,
    required String inputHash,
  }) async {
    final messages = [
      {'role': 'user', 'content': prompt},
    ];

    return await _callChat(messages: messages);
  }

  @override
  Future<Map<String, dynamic>> examinationOcr({
    required String personId,
    required String prompt,
    required String imagePath,
    required String inputHash,
  }) async {
    // TODO: 实现图片支持
    throw UnimplementedError('图片支持待实现');
  }

  @override
  Future<Map<String, dynamic>> labTestOcr({
    required String personId,
    required String prompt,
    required String imagePath,
    required String inputHash,
  }) async {
    // TODO: 实现图片支持
    throw UnimplementedError('图片支持待实现');
  }

  @override
  Future<Map<String, dynamic>> audioTranscription({
    required String personId,
    required String prompt,
    required String audioPath,
    required String inputHash,
  }) async {
    // TODO: 实现音频支持
    throw UnimplementedError('音频支持待实现');
  }

  @override
  Stream<String> generateTextStream({
    required String systemPrompt,
    required String userContent,
    Map<String, dynamic>? options,
  }) async* {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userContent},
    ];
    final response = await _adapter.chatCompletions(
      messages: messages,
      model: null,
      temperature: options?['temperature'] as double? ?? 0.7,
    );
    final content = OpenAiAdapter.extractContent(response);
    if (content.isNotEmpty) yield content;
  }
}
