import 'package:flutter/foundation.dart';

import 'audio_recorder.dart';
import 'mobile_audio_recorder.dart';

class _UnsupportedAudioRecorder implements VitalAudioRecorder {
  _UnsupportedAudioRecorder(this._platformName);
  final String _platformName;

  @override
  bool get isRecording => false;

  @override
  Future<bool> get isSupported async => false;

  @override
  Future<void> startRecording() async {
    throw RecordingException('$_platformName暂不支持录音功能，请使用移动端App进行录音');
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
      return _UnsupportedAudioRecorder('Web端');
    }
    return MobileAudioRecorder();
  }
}
