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
      debugPrint('[$serviceName] ASR 开始处理音频, audioPath 长度: ${audioPath.length}');
      final audioData = await _processAudio(audioPath);
      final audioDataPrefix = audioData.length > 80 ? audioData.substring(0, 80) : audioData;
      debugPrint(
        '[$serviceName] ASR 音频处理完成: data 长度=${audioData.length}, '
        '前缀=$audioDataPrefix...',
      );

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
      debugPrint(
        '[$serviceName] ASR 请求体: model=$audioModel, '
        'user.content[0].audio 长度=${audioData.length}',
      );

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
      final errMsg = e.toString();
      debugPrint('[$serviceName] ASR 捕获异常: $errMsg');
      if (errMsg.contains('The audio is empty') ||
          errMsg.contains('audio is empty') ||
          errMsg.contains('音频为空')) {
        if (!audioPath.startsWith('http')) {
          debugPrint(
            '[$serviceName] ASR 判定为「音频为空」类错误，原始异常: $e',
          );
          throw Exception(
            '百炼返回「音频为空」：请确认录音已完整保存（可检查附件目录下该 wav 文件大小），'
            '若文件过小或为 0 字节多为保存未完成即触发转写导致',
          );
        }
      }
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        final msg = responseData?.toString() ?? e.message ?? '';
        throw Exception(
          '百炼语音识别请求失败 [HTTP $statusCode]: $msg',
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
      final base64Content = audioPath.substring(7).trim();
      if (base64Content.isEmpty) {
        throw Exception('音频数据为空（base64 内容为空）');
      }
      debugPrint(
        '[BailianAiService] base64音频数据长度: ${base64Content.length} 字符，使用data URI格式',
      );
      return 'data:audio/mp4;base64,$base64Content';
    } else if (kIsWeb &&
        !audioPath.contains(r'\') &&
        !(audioPath.length >= 2 && audioPath[1] == ':') &&
        !audioPath.startsWith('/') &&
        !audioPath.contains('/')) {
      // 仅 Web 且明确不是路径时：当作纯 base64 字符串
      // Android/iOS 等移动端 getFilePath 返回的均为带 / 的绝对路径，不会进入此分支
      return 'data:audio/mp4;base64,$audioPath';
    } else {
      // 本地文件路径（Windows 含 \ 或 D:，Android/Unix 含 /），读取文件并转换为 base64
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('音频文件不存在：$audioPath');
      }
      final audioBytes = await audioFile.readAsBytes();

      if (audioBytes.isEmpty) {
        throw Exception('音频文件为空，请检查录音是否已正确保存：$audioPath');
      }
      // WAV 仅含文件头约 44 字节时无有效音频，百炼会返回 The audio is empty
      if (audioBytes.length < 1024) {
        throw Exception(
          '音频文件过短（${audioBytes.length} 字节），可能未正确录制或仅含文件头，请重新录音',
        );
      }
      if (audioBytes.length > 20 * 1024 * 1024) {
        throw Exception('音频文件太大，超过20MB限制');
      }

      final base64Audio = base64Encode(audioBytes);
      final mimeType = _getAudioMimeType(audioPath);
      final dataUri = 'data:$mimeType;base64,$base64Audio';
      // 日志：文件头十六进制（WAV 应为 52 49 46 46 = RIFF）
      final headHex = audioBytes.length >= 12
          ? audioBytes.sublist(0, 12).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')
          : '不足12字节';
      debugPrint(
        '[BailianAiService] 本地音频: ${audioBytes.length} 字节, '
        '文件头(hex): $headHex, data URI 总长度: ${dataUri.length}',
      );
      return dataUri;
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

    final statusCode = resp.statusCode ?? -1;
    final respData = resp.data;
    debugPrint(
      '[$serviceName] ASR 响应: HTTP $statusCode, '
      'body keys=${respData?.keys.toList() ?? []}',
    );

    if (statusCode >= 400) {
      final code = respData?['code']?.toString();
      final message = respData?['message']?.toString() ?? respData?.toString() ?? '未知错误';
      final rawBody = resp.data?.toString() ?? '';
      debugPrint(
        '[$serviceName] ASR 错误响应: HTTP $statusCode, code=$code, message=$message',
      );
      debugPrint(
        '[$serviceName] ASR 响应 body 摘要: ${rawBody.length > 500 ? rawBody.substring(0, 500) : rawBody}',
      );
      throw Exception('百炼API错误：$message');
    }

    if (respData?['code'] != null && respData?['code'] != 'Success') {
      final message = respData?['message']?.toString() ?? '未知错误';
      debugPrint('[$serviceName] ASR 业务错误: code=${respData?['code']}, message=$message');
      throw Exception('百炼API错误：$message');
    }

    return respData ?? {};
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
