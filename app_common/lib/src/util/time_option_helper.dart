/// 时间选项工具类
/// 集中处理所有时间相关的逻辑
class TimeOptionHelper {
  /// 解析时间预设为 DateTime
  /// 支持的格式：
  /// - "now": 当前时间
  /// - "-3h": 3小时前
  /// - "-1d": 1天前
  /// - "-3d": 3天前
  static DateTime? parseTimePreset(String? preset) {
    if (preset == null) return null;

    final now = DateTime.now();

    switch (preset) {
      case 'now':
        return now;
      case '-3h':
        return now.subtract(const Duration(hours: 3));
      case '-1d':
        return now.subtract(const Duration(days: 1));
      case '-3d':
        return now.subtract(const Duration(days: 3));
      default:
        // 尝试解析其他格式，如 "-5d", "-12h" 等
        if (preset.startsWith('-')) {
          final value = preset.substring(1);
          if (value.endsWith('h')) {
            final hours = int.tryParse(value.substring(0, value.length - 1));
            if (hours != null) {
              return now.subtract(Duration(hours: hours));
            }
          } else if (value.endsWith('d')) {
            final days = int.tryParse(value.substring(0, value.length - 1));
            if (days != null) {
              return now.subtract(Duration(days: days));
            }
          }
        }
        return null;
    }
  }

  /// 格式化时间为显示文本
  /// 格式：今天/昨天/N天前/完整日期时间
  static String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final isMidnight = dateTime.hour == 0 && dateTime.minute == 0;
    final timeStr = isMidnight
        ? ''
        : ' ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    // 如果是今天，只显示时间
    if (difference.inDays == 0) {
      return isMidnight ? '今天' : '今天$timeStr';
    }
    // 如果是昨天
    else if (difference.inDays == 1) {
      return isMidnight ? '昨天' : '昨天$timeStr';
    }
    // 如果是最近一周内
    else if (difference.inDays < 7) {
      return isMidnight
          ? '${difference.inDays}天前'
          : '${difference.inDays}天前$timeStr';
    }
    // 其他情况显示完整日期时间
    else {
      return isMidnight
          ? '${dateTime.year}年${dateTime.month}月${dateTime.day}日'
          : '${dateTime.year}年${dateTime.month}月${dateTime.day}日$timeStr';
    }
  }

  /// 生成存储文本（如"起始：2024年12月31日"）
  static String toStorageText(DateTime dateTime, {String prefix = '起始：'}) {
    return '$prefix${formatDateTime(dateTime)}';
  }

  /// 判断文本是否是时间存储格式
  /// 检查是否以"起始："开头，或包含年月日格式
  static bool isTimeStorageText(String text) {
    return text.startsWith('起始：') ||
        (text.contains('年') && text.contains('月') && text.contains('日'));
  }

  /// 从存储文本中提取时间文本（去除"起始："前缀）
  static String extractTimeText(String storageText) {
    if (storageText.startsWith('起始：')) {
      return storageText.substring(3); // 跳过"起始："（3个字符）
    }
    return storageText;
  }
}
