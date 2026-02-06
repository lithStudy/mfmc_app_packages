import 'dart:async';
import 'dart:typed_data';

/// 录音功能抽象接口
abstract class VitalAudioRecorder {
  /// 是否正在录音
  bool get isRecording;

  /// 是否支持录音
  Future<bool> get isSupported;

  /// 开始录音
  /// [onData] 录音数据回调（可选，用于实时处理）
  Future<void> startRecording();

  /// 停止录音
  /// 返回录音数据
  Future<Uint8List?> stopRecording();

  /// 取消录音（不保存）
  Future<void> cancelRecording();

  /// 释放资源
  Future<void> dispose();
}

/// 录音配置
class RecordingConfig {
  const RecordingConfig({
    this.sampleRate = 44100,
    this.bitRate = 128000,
    this.numChannels = 1,
    this.encoder = AudioEncoder.aac,
  });

  /// 采样率
  final int sampleRate;

  /// 比特率
  final int bitRate;

  /// 声道数
  final int numChannels;

  /// 编码器
  final AudioEncoder encoder;
}

/// 音频编码器类型
enum AudioEncoder {
  /// AAC编码 (m4a格式)
  aac,

  /// Opus编码 (webm/ogg格式)
  opus,

  /// MP3编码
  mp3,

  /// WAV编码
  wav,

  /// 平台默认编码
  defaultCodec,
}

/// 录音异常
class RecordingException implements Exception {
  RecordingException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() =>
      'RecordingException: $message${code != null ? ' ($code)' : ''}';
}
