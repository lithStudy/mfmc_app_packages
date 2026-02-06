import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'openai_compatible_ai_service.dart';

/// 智普AI服务实现
/// 继承OpenAI兼容基类，支持直连或通过后端路由转发
/// 音频转录使用智普专用的ASR接口（multipart/form-data格式）
class ZhipuAiService extends OpenAiCompatibleAiService {
  ZhipuAiService({
    required super.apiKey,
    required super.backendUrl,
    super.endpoint,
    super.model,
    super.visionModel,
    super.audioModel,
    Dio? dio,
  }) : super(dio: dio);

  @override
  String get serviceName => '智普';

  @override
  String get defaultEndpoint =>
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  @override
  String get defaultModel => 'glm-4.7';

  @override
  String get defaultVisionModel => 'glm-4.6v';

  @override
  String get defaultAudioModel => 'glm-asr-2512';

  /// 智普音频转录功能
  /// 使用配置的语音模型，调用智普ASR专用接口
  /// 接口使用 multipart/form-data 格式上传音频文件
  @override
  Future<Map<String, dynamic>> audioTranscription({
    required String personId,
    required String prompt,
    required String audioPath,
    required String inputHash,
  }) async {
    const asrEndpoint =
        'https://open.bigmodel.cn/api/paas/v4/audio/transcriptions';

    try {
      // 处理音频数据，获取字节数据和文件名
      final audioInfo = await _processAudioForMultipart(audioPath);
      final audioBytes = audioInfo['bytes'] as Uint8List;
      final fileName = audioInfo['fileName'] as String;
      final mimeType = audioInfo['mimeType'] as String;

      debugPrint(
        '[$serviceName] ASR 音频文件: $fileName, 大小: ${audioBytes.length} bytes',
      );

      // 调用智普ASR接口
      final response = await _callZhipuAsrApi(
        asrEndpoint,
        audioBytes,
        fileName,
        mimeType,
      );

      // 提取识别文本
      final transcribedText = response['text']?.toString() ?? '';

      if (transcribedText.isEmpty) {
        throw Exception('智普语音识别返回内容为空');
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
          '智普语音识别请求失败 [HTTP $statusCode]: ${responseData?.toString() ?? e.message}',
        );
      }
      rethrow;
    }
  }

  /// 处理音频数据，返回用于multipart上传的信息
  Future<Map<String, dynamic>> _processAudioForMultipart(
    String audioPath,
  ) async {
    String subAudioPath = audioPath.length > 100
        ? audioPath.substring(0, 100)
        : audioPath;
    debugPrint('[$serviceName] audioPath: $subAudioPath');

    Uint8List audioBytes;
    String fileName;
    String mimeType;

    if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
      // URL格式，需要先下载
      final dio = Dio();
      final response = await dio.get<List<int>>(
        audioPath,
        options: Options(responseType: ResponseType.bytes),
      );
      audioBytes = Uint8List.fromList(response.data!);
      fileName = audioPath.split('/').last.split('?').first;
      if (!fileName.contains('.')) {
        fileName = 'audio.mp4';
      }
      mimeType = _getAudioMimeType(fileName);
    } else if (audioPath.startsWith('data:')) {
      // data:audio/xxx;base64,xxx 格式
      final commaIndex = audioPath.indexOf(',');
      if (commaIndex == -1) {
        throw Exception('无效的data URI格式');
      }
      final base64Content = audioPath.substring(commaIndex + 1);
      audioBytes = base64Decode(base64Content);
      // 从data URI中提取MIME类型
      final mimeMatch = RegExp(r'data:([^;]+)').firstMatch(audioPath);
      mimeType = mimeMatch?.group(1) ?? 'audio/mp4';
      fileName = 'audio.${_getExtensionFromMimeType(mimeType)}';
    } else if (audioPath.startsWith('base64:')) {
      // base64:xxx 格式（来自AttachmentStorage）
      final base64Content = audioPath.substring(7);
      audioBytes = base64Decode(base64Content);
      mimeType = 'audio/mp4';
      fileName = 'audio.m4a';
    } else if (kIsWeb || !audioPath.contains('/')) {
      // Web平台或其他情况，假设是纯base64字符串
      audioBytes = base64Decode(audioPath);
      mimeType = 'audio/mp4';
      fileName = 'audio.m4a';
    } else {
      // 本地文件路径
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('音频文件不存在：$audioPath');
      }
      audioBytes = await audioFile.readAsBytes();
      fileName = audioPath.split('/').last;
      mimeType = _getAudioMimeType(audioPath);
    }

    // 检查文件大小限制（25MB）
    if (audioBytes.length > 25 * 1024 * 1024) {
      throw Exception('音频文件太大，超过25MB限制');
    }

    return {'bytes': audioBytes, 'fileName': fileName, 'mimeType': mimeType};
  }

  /// 根据文件扩展名获取音频MIME类型
  String _getAudioMimeType(String path) {
    final extension = path.toLowerCase();
    if (extension.endsWith('.wav')) return 'audio/wav';
    if (extension.endsWith('.mp3')) return 'audio/mpeg';
    if (extension.endsWith('.aac')) return 'audio/aac';
    if (extension.endsWith('.ogg')) return 'audio/ogg';
    if (extension.endsWith('.flac')) return 'audio/flac';
    if (extension.endsWith('.webm')) return 'audio/webm';
    return 'audio/mp4'; // 默认m4a使用mp4
  }

  /// 根据MIME类型获取文件扩展名
  String _getExtensionFromMimeType(String mimeType) {
    switch (mimeType) {
      case 'audio/wav':
        return 'wav';
      case 'audio/mpeg':
        return 'mp3';
      case 'audio/aac':
        return 'aac';
      case 'audio/ogg':
        return 'ogg';
      case 'audio/flac':
        return 'flac';
      case 'audio/webm':
        return 'webm';
      default:
        return 'm4a';
    }
  }

  /// 调用智普ASR接口（multipart/form-data格式）
  Future<Map<String, dynamic>> _callZhipuAsrApi(
    String endpoint,
    Uint8List audioBytes,
    String fileName,
    String mimeType,
  ) async {
    final dio = Dio()
      ..options.connectTimeout = const Duration(seconds: 60)
      ..options.receiveTimeout = const Duration(seconds: 180)
      ..options.validateStatus = (status) => status != null && status < 500;

    debugPrint('[$serviceName] ASR backendUrl: "$backendUrl"');
    debugPrint('[$serviceName] ASR endpoint: $endpoint');

    Response<Map<String, dynamic>> resp;

    if (backendUrl.isNotEmpty) {
      // 通过后端路由转发（Web端解决跨域）
      // 后端代理需要支持multipart转发，这里使用base64编码传输
      debugPrint('[$serviceName] ASR 使用后端转发');
      resp = await dio.post<Map<String, dynamic>>(
        '$backendUrl/api/ai/proxy',
        data: {
          'url': endpoint,
          'method': 'POST',
          'headers': {'Authorization': 'Bearer $apiKey'},
          'multipart': {
            'model': audioModel,
            'file': {
              'data': base64Encode(audioBytes),
              'filename': fileName,
              'contentType': mimeType,
            },
          },
        },
      );
    } else {
      // 直连AI API（Android端）
      debugPrint('[$serviceName] ASR 直连AI API');

      final formData = FormData.fromMap({
        'model': audioModel,
        'file': MultipartFile.fromBytes(
          audioBytes,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      resp = await dio.post<Map<String, dynamic>>(
        endpoint,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );
    }

    // 检查API返回的错误
    if (resp.data?['error'] != null) {
      final error = resp.data!['error'];
      final message = error['message']?.toString() ?? error.toString();
      throw Exception('智普ASR API错误：$message');
    }

    return resp.data ?? {};
  }
}
