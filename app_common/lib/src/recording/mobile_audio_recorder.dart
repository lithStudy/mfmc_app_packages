import 'dart:async';
import 'dart:typed_data';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;

import '../util/app_logger.dart';
import 'audio_recorder.dart';

/// 移动端录音实现（使用record包）
class MobileAudioRecorder implements VitalAudioRecorder {
  record.AudioRecorder? _recorder;
  bool _isRecording = false;
  String? _currentPath;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<bool> get isSupported async {
    try {
      _recorder ??= record.AudioRecorder();
      final hasPermission = await _recorder!.hasPermission();
      await AppLogger.info(
        'Mobile录音: 权限检查结果: $hasPermission',
        tag: 'AudioRecorder',
      );
      debugPrint('Mobile录音: 权限检查结果: $hasPermission');
      return hasPermission;
    } catch (e) {
      await AppLogger.error('Mobile录音: 权限检查失败: $e', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 权限检查失败: $e');
      return false;
    }
  }

  @override
  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      await AppLogger.info('Mobile录音: 初始化录音器...', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 初始化录音器...');
      _recorder ??= record.AudioRecorder();

      await AppLogger.info('Mobile录音: 检查权限...', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 检查权限...');
      // 检查权限
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        await AppLogger.error('Mobile录音: 没有录音权限', tag: 'AudioRecorder');
        throw RecordingException('没有录音权限，请在系统设置中开启麦克风权限');
      }
      await AppLogger.info('Mobile录音: 权限检查通过', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 权限检查通过');

      // 获取临时目录路径
      final tempDir = await getTemporaryDirectory();
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      _currentPath = '${tempDir.path}/$fileName';
      await AppLogger.info(
        'Mobile录音: 录音文件路径: $_currentPath',
        tag: 'AudioRecorder',
      );
      debugPrint('Mobile录音: 录音文件路径: $_currentPath');

      await AppLogger.info('Mobile录音: 开始录音...', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 开始录音...');

      // 使用WAV格式 (16kHz, 16-bit, 单声道)，解决Android端长语音无法识别的问题
      // 百炼API对Android默认的AAC/m4a格式支持不稳定，特别是超过5秒的音频
      final config = const record.RecordConfig(
        encoder: record.AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );

      // 开始录音
      await _recorder!.start(config, path: _currentPath!);

      _isRecording = true;
      await AppLogger.info('Mobile录音: 录音开始成功', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 录音开始成功');
    } catch (e, stackTrace) {
      await AppLogger.error('Mobile录音: 开始录音失败: $e', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 开始录音失败: $e');
      debugPrint('Mobile录音: 堆栈跟踪: $stackTrace');

      // 清理可能的临时文件
      if (_currentPath != null && File(_currentPath!).existsSync()) {
        try {
          File(_currentPath!).deleteSync();
          debugPrint('Mobile录音: 清理临时文件: $_currentPath');
        } catch (cleanupError) {
          debugPrint('Mobile录音: 清理临时文件失败: $cleanupError');
        }
      }

      _currentPath = null;
      // 重新抛出更用户友好的异常
      if (e.toString().contains('permission')) {
        throw RecordingException('录音权限被拒绝，请检查应用权限设置');
      } else {
        throw RecordingException('录音初始化失败，请重试或检查设备状态');
      }
    }
  }

  @override
  Future<Uint8List?> stopRecording() async {
    if (!_isRecording || _currentPath == null) {
      await AppLogger.warning('Mobile录音: 停止录音条件不满足', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 停止录音条件不满足');
      return null;
    }

    try {
      await AppLogger.info('Mobile录音: 停止录音...', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 停止录音...');
      _recorder ??= record.AudioRecorder();

      // 停止录音
      final path = await _recorder!.stop();
      _isRecording = false;
      await AppLogger.info('Mobile录音: 录音停止，返回路径: $path', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 录音停止，返回路径: $path');

      if (path == null) {
        await AppLogger.warning('Mobile录音: 返回路径为空', tag: 'AudioRecorder');
        debugPrint('Mobile录音: 返回路径为空');
        return null;
      }

      // 读取录音文件
      await AppLogger.info('Mobile录音: 读取录音文件...', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 读取录音文件...');
      final file = File(path);
      final bytes = await file.readAsBytes();
      await AppLogger.info(
        'Mobile录音: 录音文件大小: ${bytes.length} bytes',
        tag: 'AudioRecorder',
      );
      debugPrint('Mobile录音: 录音文件大小: ${bytes.length} bytes');

      _currentPath = null;
      return bytes;
    } catch (e, stackTrace) {
      await AppLogger.error('Mobile录音: 停止录音失败: $e', tag: 'AudioRecorder');
      debugPrint('Mobile录音: 停止录音失败: $e');
      debugPrint('Mobile录音: 堆栈跟踪: $stackTrace');
      _currentPath = null;
      _isRecording = false;
      throw RecordingException('停止录音失败: $e');
    }
  }

  @override
  Future<void> cancelRecording() async {
    if (_isRecording) {
      _recorder ??= record.AudioRecorder();
      await _recorder!.stop();
    }

    // 清理临时文件
    if (_currentPath != null && File(_currentPath!).existsSync()) {
      try {
        File(_currentPath!).deleteSync();
        debugPrint('Mobile录音: 取消录音时清理临时文件: $_currentPath');
      } catch (cleanupError) {
        debugPrint('Mobile录音: 清理临时文件失败: $cleanupError');
      }
    }

    _isRecording = false;
    _currentPath = null;
  }

  @override
  Future<void> dispose() async {
    await cancelRecording();
    if (_recorder != null) {
      await _recorder!.dispose();
      _recorder = null;
    }
  }
}
