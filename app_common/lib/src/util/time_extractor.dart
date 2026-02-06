import 'time_util.dart';

/// 时间提取结果
class TimeExtractionResult {
  const TimeExtractionResult({
    required this.occurredAtIso,
    required this.isPrecise,
    this.timeDescription,
  });

  /// 解析后的时间（ISO 8601格式）
  final String occurredAtIso;

  /// 是否为精确时间
  final bool isPrecise;

  /// 时间描述（如"昨天"、"前天中午"等），用于显示
  final String? timeDescription;
}

/// 本地时间提取器：快速解析常见时间模式
class TimeExtractor {
  /// 从文本中提取时间信息
  ///
  /// 支持的格式：
  /// - "昨天"、"前天"、"大前天"
  /// - "今天"、"今天中午"、"今天下午"、"今天晚上"
  /// - "昨天中午"、"昨天下午"、"昨天晚上"
  /// - "前天中午"、"前天下午"、"前天晚上"
  /// - "上午"、"中午"、"下午"、"晚上"
  /// - "HH:mm"、"HH：mm" (如 "22:30" 或 "22：30")
  static TimeExtractionResult extract(String text) {
    final now = DateTime.now();
    final textLower = text.toLowerCase().trim();

    // 检查是否包含时间相关关键词
    final hasTimeKeyword = _hasTimeKeyword(textLower);
    if (!hasTimeKeyword) {
      // 没有时间关键词，返回当前时间，标记为精确
      return TimeExtractionResult(occurredAtIso: nowIso(), isPrecise: true);
    }

    // 提取日期偏移
    int dayOffset = 0;
    if (textLower.contains('大前天')) {
      dayOffset = 3;
    } else if (textLower.contains('前天')) {
      dayOffset = 2;
    } else if (textLower.contains('昨天')) {
      dayOffset = 1;
    } else if (textLower.contains('今天')) {
      dayOffset = 0;
    }

    // 提取时间段
    int hour = 12; // 默认中午
    int minute = 0;
    String? timeDescription;

    // 尝试匹配 HH:mm 格式
    final timeMatch = RegExp(r'(\d{1,2})[:：](\d{1,2})').firstMatch(textLower);
    if (timeMatch != null) {
      hour = int.tryParse(timeMatch.group(1) ?? '') ?? hour;
      minute = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
      // 保证小时在合理范围内
      if (hour < 0 || hour > 23) hour = 12;
      if (minute < 0 || minute > 59) minute = 0;
    } else if (textLower.contains('上午') ||
        textLower.contains('早上') ||
        textLower.contains('早晨')) {
      hour = 9;
      timeDescription = dayOffset == 0
          ? '今天上午'
          : dayOffset == 1
          ? '昨天上午'
          : '前天上午';
    } else if (textLower.contains('中午') || textLower.contains('正午')) {
      hour = 12;
      timeDescription = dayOffset == 0
          ? '今天中午'
          : dayOffset == 1
          ? '昨天中午'
          : '前天中午';
    } else if (textLower.contains('下午')) {
      hour = 15;
      timeDescription = dayOffset == 0
          ? '今天下午'
          : dayOffset == 1
          ? '昨天下午'
          : '前天下午';
    } else if (textLower.contains('晚上') ||
        textLower.contains('傍晚') ||
        textLower.contains('夜间')) {
      hour = 20;
      timeDescription = dayOffset == 0
          ? '今天晚上'
          : dayOffset == 1
          ? '昨天晚上'
          : '前天晚上';
    } else {
      // 只有日期偏移，没有时间段
      if (dayOffset == 0) {
        timeDescription = '今天';
      } else if (dayOffset == 1) {
        timeDescription = '昨天';
      } else if (dayOffset == 2) {
        timeDescription = '前天';
      } else if (dayOffset == 3) {
        timeDescription = '大前天';
      }
    }

    // 计算目标时间
    final targetDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
      0,
    ).subtract(Duration(days: dayOffset));

    return TimeExtractionResult(
      occurredAtIso: targetDate.toUtc().toIso8601String(),
      isPrecise: false, // 范围性时间标记为不精确
      timeDescription: timeDescription,
    );
  }

  /// 检查文本是否包含时间相关关键词
  static bool _hasTimeKeyword(String text) {
    final keywords = [
      '昨天',
      '前天',
      '大前天',
      '今天',
      '上午',
      '中午',
      '下午',
      '晚上',
      '早上',
      '早晨',
      '正午',
      '傍晚',
      '夜间',
    ];
    return keywords.any((keyword) => text.contains(keyword));
  }
}
