import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final String? tag;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
  });

  String get formattedTime {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  String toFormattedString() {
    final tagStr = tag != null ? '[$tag] ' : '';
    return '${formattedTime} [$level] $tagStr$message';
  }
}

class LoggerService {
  LoggerService._();
  static LoggerService? _instance;
  static Future<LoggerService> getInstance() async {
    _instance ??= LoggerService._();
    if (!kIsWeb) {
      await _instance!._ensureDirectory();
    }
    return _instance!;
  }

  String? _logsDir;
  File? _currentLogFile;
  final int _maxLogFileSize = 5 * 1024 * 1024; // 5MB
  final int _maxLogFiles = 10; // 最多保留10个日志文件
  final List<LogEntry> _inMemoryLogs = [];
  final int _maxInMemoryLogs = 1000; // 内存中最多保留1000条日志

  Future<void> _ensureDirectory() async {
    if (_logsDir != null) return;
    if (kIsWeb) return;

    Directory? baseDir;

    if (Platform.isAndroid) {
      try {
        // Android平台：优先使用应用文档目录（应用专用目录，无需额外权限）
        baseDir = await getApplicationDocumentsDirectory();
        debugPrint('[LoggerService] 使用应用文档目录: ${baseDir.path}');
      } catch (e) {
        debugPrint('[LoggerService] 获取应用文档目录失败: $e');
        // 如果失败，尝试使用外部存储目录
        try {
          final externalDirs = await getExternalStorageDirectories();
          if (externalDirs != null && externalDirs.isNotEmpty) {
            baseDir = externalDirs.first;
            debugPrint('[LoggerService] 使用外部存储目录: ${baseDir.path}');
          }
        } catch (e2) {
          debugPrint('[LoggerService] 获取外部存储目录也失败: $e2');
        }
      }
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    if (baseDir == null) {
      debugPrint('[LoggerService] 无法获取任何目录，日志功能将不可用');
      return;
    }

    final logsDir = p.join(baseDir.path, 'logs');
    debugPrint('[LoggerService] 日志目录: $logsDir');

    try {
      final dir = Directory(logsDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        debugPrint('[LoggerService] 创建日志目录成功');
      } else {
        debugPrint('[LoggerService] 日志目录已存在');
      }
      _logsDir = logsDir;
      await _initializeLogFile();
    } catch (e) {
      debugPrint('[LoggerService] 创建日志目录失败: $e');
      debugPrint('[LoggerService] 堆栈: ${StackTrace.current}');
    }
  }

  Future<void> _initializeLogFile() async {
    if (_logsDir == null) {
      debugPrint('[LoggerService] 日志目录为空，无法初始化日志文件');
      return;
    }

    try {
      final now = DateTime.now();
      final fileName =
          'log_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.txt';
      final filePath = p.join(_logsDir!, fileName);
      _currentLogFile = File(filePath);
      debugPrint('[LoggerService] 当前日志文件: $filePath');

      // 如果文件太大，创建新文件
      if (await _currentLogFile!.exists()) {
        final size = await _currentLogFile!.length();
        debugPrint('[LoggerService] 当前日志文件大小: $size 字节');
        if (size > _maxLogFileSize) {
          final timestamp = now.millisecondsSinceEpoch;
          final newFileName =
              'log_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_$timestamp.txt';
          final newFilePath = p.join(_logsDir!, newFileName);
          _currentLogFile = File(newFilePath);
          debugPrint('[LoggerService] 日志文件过大，创建新文件: $newFilePath');
        }
      } else {
        debugPrint('[LoggerService] 日志文件不存在，将创建新文件');
      }

      // 清理旧日志文件
      await _cleanOldLogFiles();
      debugPrint('[LoggerService] 日志文件初始化完成');
    } catch (e) {
      debugPrint('[LoggerService] 初始化日志文件失败: $e');
      debugPrint('[LoggerService] 堆栈: ${StackTrace.current}');
    }
  }

  Future<void> _cleanOldLogFiles() async {
    if (_logsDir == null) return;

    try {
      final dir = Directory(_logsDir!);
      if (!await dir.exists()) return;

      final files = await dir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .cast<File>()
          .toList();

      // 按修改时间排序，最新的在前
      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );

      // 删除超出数量的旧文件
      if (files.length > _maxLogFiles) {
        for (var i = _maxLogFiles; i < files.length; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      debugPrint('清理旧日志文件失败: $e');
    }
  }

  Future<void> log(String level, String message, {String? tag}) async {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
    );

    // 添加到内存日志
    _inMemoryLogs.add(entry);
    if (_inMemoryLogs.length > _maxInMemoryLogs) {
      _inMemoryLogs.removeAt(0);
    }

    // 写入文件
    if (!kIsWeb && _currentLogFile != null) {
      try {
        final logLine = '${entry.toFormattedString()}\n';
        await _currentLogFile!.writeAsString(logLine, mode: FileMode.append);
      } catch (e, stackTrace) {
        debugPrint('[LoggerService] 写入日志文件失败: $e');
        debugPrint('[LoggerService] 文件路径: ${_currentLogFile!.path}');
        debugPrint(
          '[LoggerService] 文件是否存在: ${await _currentLogFile!.exists()}',
        );
        debugPrint('[LoggerService] 堆栈: $stackTrace');
        // 如果写入失败，尝试重新初始化日志文件
        if (_logsDir != null) {
          try {
            await _initializeLogFile();
          } catch (e2) {
            debugPrint('[LoggerService] 重新初始化日志文件也失败: $e2');
          }
        }
      }
    } else if (!kIsWeb) {
      debugPrint('[LoggerService] 警告: 当前日志文件为空，无法写入日志');
      debugPrint('[LoggerService] _logsDir: $_logsDir');
      debugPrint('[LoggerService] _currentLogFile: $_currentLogFile');
    }
  }

  Future<void> debug(String message, {String? tag}) async {
    await log('DEBUG', message, tag: tag);
  }

  Future<void> info(String message, {String? tag}) async {
    await log('INFO', message, tag: tag);
  }

  Future<void> warning(String message, {String? tag}) async {
    await log('WARN', message, tag: tag);
  }

  Future<void> error(String message, {String? tag}) async {
    await log('ERROR', message, tag: tag);
  }

  /// 获取内存中的日志（按时间倒序）
  List<LogEntry> getInMemoryLogs() {
    return List.unmodifiable(_inMemoryLogs.reversed);
  }

  /// 从文件读取日志（按时间倒序）
  Future<List<LogEntry>> getLogsFromFile({int? limit}) async {
    if (kIsWeb || _logsDir == null) {
      return [];
    }

    try {
      final dir = Directory(_logsDir!);
      if (!await dir.exists()) {
        return [];
      }

      final files = await dir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .cast<File>()
          .toList();

      // 按修改时间排序，最新的在前
      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );

      final List<LogEntry> entries = [];

      for (final file in files) {
        if (limit != null && entries.length >= limit) break;

        try {
          final content = await file.readAsString();
          final lines = content.split('\n');

          for (final line in lines.reversed) {
            if (line.trim().isEmpty) continue;
            if (limit != null && entries.length >= limit) break;

            // 解析日志行：格式为 "时间 [级别] [标签] 消息"
            final entry = _parseLogLine(line);
            if (entry != null) {
              entries.add(entry);
            }
          }
        } catch (e) {
          debugPrint('读取日志文件失败 ${file.path}: $e');
        }
      }

      // 按时间倒序排序
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return entries;
    } catch (e) {
      debugPrint('获取日志失败: $e');
      return [];
    }
  }

  LogEntry? _parseLogLine(String line) {
    try {
      // 格式：2024-01-01 12:00:00.000 [LEVEL] [tag] message
      final regex = RegExp(
        r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}) \[(\w+)\] (?:\[(\w+)\] )?(.+)$',
      );
      final match = regex.firstMatch(line);
      if (match == null) {
        // 如果解析失败，创建一个默认条目
        return LogEntry(
          timestamp: DateTime.now(),
          level: 'UNKNOWN',
          message: line,
        );
      }

      final timeStr = match.group(1)!;
      final level = match.group(2)!;
      final tag = match.group(3);
      final message = match.group(4)!;

      // 解析时间
      final dateTime = _parseDateTime(timeStr);
      if (dateTime == null) {
        return LogEntry(
          timestamp: DateTime.now(),
          level: level,
          message: message,
          tag: tag,
        );
      }

      return LogEntry(
        timestamp: dateTime,
        level: level,
        message: message,
        tag: tag,
      );
    } catch (e) {
      return null;
    }
  }

  DateTime? _parseDateTime(String timeStr) {
    try {
      // 格式：2024-01-01 12:00:00.000
      final parts = timeStr.split(' ');
      if (parts.length != 2) return null;

      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');
      if (dateParts.length != 3 || timeParts.length != 3) return null;

      final millisecondPart = timeParts[2].split('.');
      if (millisecondPart.length != 2) return null;

      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(millisecondPart[0]),
        int.parse(millisecondPart[1]),
      );
    } catch (e) {
      return null;
    }
  }

  /// 清除所有日志
  Future<void> clearLogs() async {
    _inMemoryLogs.clear();
    if (kIsWeb || _logsDir == null) return;

    try {
      final dir = Directory(_logsDir!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
      await _initializeLogFile();
    } catch (e) {
      debugPrint('清除日志失败: $e');
    }
  }

  /// 获取日志目录路径
  Future<String?> getLogsDirectoryPath() async {
    if (kIsWeb) return null;
    await _ensureDirectory();
    return _logsDir;
  }

  /// 导出所有日志到指定文件路径
  Future<void> exportAllLogsToFile(String filePath) async {
    try {
      // 获取所有文件日志（不限制数量）
      final fileLogs = await getLogsFromFile();

      // 获取所有内存日志
      final memoryLogs = getInMemoryLogs();

      // 合并日志，去重（基于时间戳和消息）
      final Map<String, LogEntry> uniqueLogs = {};

      // 先添加文件日志
      for (final log in fileLogs) {
        final key = '${log.timestamp.millisecondsSinceEpoch}_${log.message}';
        if (!uniqueLogs.containsKey(key)) {
          uniqueLogs[key] = log;
        }
      }

      // 再添加内存日志
      for (final log in memoryLogs) {
        final key = '${log.timestamp.millisecondsSinceEpoch}_${log.message}';
        uniqueLogs[key] = log;
      }

      // 转换为列表并按时间正序排序（从旧到新）
      final allLogs = uniqueLogs.values.toList();
      allLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // 写入文件
      final file = File(filePath);
      final buffer = StringBuffer();
      for (final log in allLogs) {
        buffer.writeln(log.toFormattedString());
      }

      await file.writeAsString(buffer.toString());
      debugPrint('[LoggerService] 日志导出成功，共 ${allLogs.length} 条，保存到: $filePath');
    } catch (e, stackTrace) {
      debugPrint('[LoggerService] 导出日志失败: $e');
      debugPrint('[LoggerService] 堆栈: $stackTrace');
      rethrow;
    }
  }

  /// 获取所有日志（用于Web平台导出）
  Future<String> getAllLogsAsString() async {
    try {
      // 获取所有文件日志（不限制数量）
      final fileLogs = await getLogsFromFile();

      // 获取所有内存日志
      final memoryLogs = getInMemoryLogs();

      // 合并日志，去重
      final Map<String, LogEntry> uniqueLogs = {};

      for (final log in fileLogs) {
        final key = '${log.timestamp.millisecondsSinceEpoch}_${log.message}';
        if (!uniqueLogs.containsKey(key)) {
          uniqueLogs[key] = log;
        }
      }

      for (final log in memoryLogs) {
        final key = '${log.timestamp.millisecondsSinceEpoch}_${log.message}';
        uniqueLogs[key] = log;
      }

      // 转换为列表并按时间正序排序
      final allLogs = uniqueLogs.values.toList();
      allLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // 生成字符串
      final buffer = StringBuffer();
      for (final log in allLogs) {
        buffer.writeln(log.toFormattedString());
      }

      return buffer.toString();
    } catch (e, stackTrace) {
      debugPrint('[LoggerService] 获取所有日志失败: $e');
      debugPrint('[LoggerService] 堆栈: $stackTrace');
      rethrow;
    }
  }
}
