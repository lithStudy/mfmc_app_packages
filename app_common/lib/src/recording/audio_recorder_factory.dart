import 'package:flutter/foundation.dart';

import 'audio_recorder.dart';
import 'mobile_audio_recorder.dart';

// Web录音器实现内联，避免条件导入问题
class WebAudioRecorderStub implements VitalAudioRecorder {
  @override
  bool get isRecording => false;

  @override
  Future<bool> get isSupported async => false;

  @override
  Future<void> startRecording() async {
    throw RecordingException('Web端录音功能暂时不可用，请使用移动端App进行录音');
  }

  @override
  Future<Uint8List?> stopRecording() async => null;

  @override
  Future<void> cancelRecording() async {}

  @override
  Future<void> dispose() async {}
}

/// 录音器工厂类
class AudioRecorderFactory {
  /// 创建平台适配的录音器实例
  static VitalAudioRecorder create() {
    if (kIsWeb) {
      return WebAudioRecorderStub();
    } else {
      return MobileAudioRecorder();
    }
  }
}
