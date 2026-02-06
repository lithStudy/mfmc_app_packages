import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'openai_compatible_ai_service.dart';

/// 阿里云百炼AI服务实现
/// 继承OpenAI兼容基类，支持直连或通过后端路由转发
/// 音频转录使用百炼独有的ASR接口
class BailianAiService extends OpenAiCompatibleAiService {
  BailianAiService({
    required super.apiKey,
    required super.backendUrl,
    super.endpoint,
    super.model,
    super.visionModel,
    super.audioModel,
    Dio? dio,
  }) : super(dio: dio);

  @override
  String get serviceName => '百炼';

  @override
  String get defaultEndpoint =>
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';

  @override
  String get defaultModel => 'qwen-plus';

  @override
  String get defaultVisionModel => 'qwen-vl-max';

  @override
  String get defaultAudioModel => 'qwen3-asr-flash';

  /// 百炼独有的音频转录功能
  /// 使用配置的语音模型，调用百炼原生API格式
  @override
  Future<Map<String, dynamic>> audioTranscription({
    required String personId,
    required String prompt,
    required String audioPath,
    required String inputHash,
  }) async {
    final asrEndpoint =
        'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';

    try {
      // 处理音频数据
      final audioData = await _processAudio(audioPath);

      // 构建语音识别请求体（百炼原生格式）
      final asrBody = {
        'model': audioModel,
        'input': {
          'messages': [
            {
              'role': 'system',
              'content': [
                {'text': ''}, // 用于配置定制化识别的Context，可以为空
              ],
            },
            {
              'role': 'user',
              'content': [
                {'audio': audioData},
              ],
            },
          ],
        },
        'parameters': {
          'asr_options': {
            'enable_itn': false, // 是否启用逆文本规范化
          },
        },
      };

      // 调用百炼原生API
      final response = await _callBailianNativeApi(asrEndpoint, asrBody);
      final output = response['output'];
      if (output == null) {
        throw Exception('百炼语音识别返回格式错误：缺少output字段');
      }

      // 提取识别文本
      final transcribedText = _extractTranscribedText(output);

      if (transcribedText.isEmpty) {
        throw Exception('百炼语音识别返回内容为空');
      }

      return {
        'text': transcribedText,
        'content': transcribedText,
        'raw': response,
      };
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        throw Exception(
          '百炼语音识别请求失败 [HTTP $statusCode]: ${responseData?.toString() ?? e.message}',
        );
      }
      rethrow;
    }
  }

  /// 处理音频数据，返回data URI格式
  Future<String> _processAudio(String audioPath) async {
    String subAudioPath = audioPath.length > 100
        ? audioPath.substring(0, 100)
        : audioPath;
    debugPrint('audioPath: $subAudioPath');

    if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
      // 已经是URL，直接使用
      return audioPath;
    } else if (audioPath.startsWith('data:')) {
      // data:audio/xxx;base64,xxx 格式，直接使用
      return audioPath;
    } else if (audioPath.startsWith('base64:')) {
      // base64:xxx 格式（来自AttachmentStorage）
      final base64Content = audioPath.substring(7);
      debugPrint(
        '[BailianAiService] base64音频数据长度: ${base64Content.length} 字符，使用data URI格式',
      );
      return 'data:audio/mp4;base64,$base64Content';
    } else if (kIsWeb || !audioPath.contains('/')) {
      // Web平台或其他情况，假设是纯base64字符串
      return 'data:audio/mp4;base64,$audioPath';
    } else {
      // 本地文件路径，读取文件并转换为base64
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('音频文件不存在：$audioPath');
      }
      final audioBytes = await audioFile.readAsBytes();

      if (audioBytes.length > 20 * 1024 * 1024) {
        throw Exception('音频文件太大，超过20MB限制');
      }

      final base64Audio = base64Encode(audioBytes);
      final mimeType = _getAudioMimeType(audioPath);
      return 'data:$mimeType;base64,$base64Audio';
    }
  }

  /// 根据文件扩展名获取音频MIME类型
  String _getAudioMimeType(String path) {
    final extension = path.toLowerCase();
    if (extension.endsWith('.wav')) return 'audio/wav';
    if (extension.endsWith('.mp3')) return 'audio/mpeg';
    if (extension.endsWith('.aac')) return 'audio/aac';
    if (extension.endsWith('.ogg')) return 'audio/ogg';
    if (extension.endsWith('.flac')) return 'audio/flac';
    return 'audio/mp4'; // 默认m4a使用mp4
  }

  /// 调用百炼原生API（用于ASR等非OpenAI兼容接口）
  Future<Map<String, dynamic>> _callBailianNativeApi(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final dio = Dio()
      ..options.connectTimeout = const Duration(seconds: 60)
      ..options.receiveTimeout = const Duration(seconds: 180)
      ..options.validateStatus = (status) => status != null && status < 500;

    Response<Map<String, dynamic>> resp;

    debugPrint('[$serviceName] ASR backendUrl: "$backendUrl"');
    debugPrint('[$serviceName] ASR endpoint: $endpoint');

    if (backendUrl.isNotEmpty) {
      // 通过后端路由转发（Web端解决跨域）
      debugPrint('[$serviceName] ASR 使用后端转发');
      resp = await dio.post<Map<String, dynamic>>(
        '$backendUrl/api/ai/proxy',
        data: {
          'url': endpoint,
          'method': 'POST',
          'headers': headers,
          'body': body,
        },
      );
    } else {
      // 直连AI API（Android端）
      debugPrint('[$serviceName] ASR 直连AI API');
      resp = await dio.post<Map<String, dynamic>>(
        endpoint,
        data: body,
        options: Options(headers: headers),
      );
    }

    if (resp.data?['code'] != null && resp.data?['code'] != 'Success') {
      final message = resp.data?['message']?.toString() ?? '未知错误';
      throw Exception('百炼API错误：$message');
    }

    return resp.data ?? {};
  }

  /// 从ASR响应中提取识别文本
  String _extractTranscribedText(Map<String, dynamic> output) {
    // 优先从 choices[0].message.content[0].text 提取
    final choices = output['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      final firstChoice = choices.first as Map?;
      if (firstChoice != null) {
        final message = firstChoice['message'] as Map?;
        if (message != null) {
          final content = message['content'] as List?;
          if (content != null && content.isNotEmpty) {
            final firstContent = content.first as Map?;
            if (firstContent != null && firstContent['text'] != null) {
              return firstContent['text'].toString().trim();
            }
          }
        }
      }
    }

    // 尝试其他可能的格式（兼容性处理）
    if (output['text'] != null) {
      return output['text'].toString().trim();
    }

    if (output['transcripts'] != null) {
      final transcripts = output['transcripts'] as List?;
      if (transcripts != null && transcripts.isNotEmpty) {
        final textList = <String>[];
        for (final transcript in transcripts) {
          if (transcript is Map && transcript['text'] != null) {
            final text = transcript['text'].toString().trim();
            if (text.isNotEmpty) {
              textList.add(text);
            }
          }
        }
        return textList.join('\n');
      }
    }

    return '';
  }
}
