/// 季节枚举
enum Season {
  spring,
  summer,
  autumn,
  winter;

  /// 从字符串转换
  static Season? fromString(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'spring':
        return Season.spring;
      case 'summer':
        return Season.summer;
      case 'autumn':
        return Season.autumn;
      case 'winter':
        return Season.winter;
      default:
        return null;
    }
  }

  /// 转换为字符串
  String toValue() {
    switch (this) {
      case Season.spring:
        return 'spring';
      case Season.summer:
        return 'summer';
      case Season.autumn:
        return 'autumn';
      case Season.winter:
        return 'winter';
    }
  }

  /// 获取显示名称
  String get displayName {
    switch (this) {
      case Season.spring:
        return '春季';
      case Season.summer:
        return '夏季';
      case Season.autumn:
        return '秋季';
      case Season.winter:
        return '冬季';
    }
  }
}

/// 环境数据模型
class EnvironmentData {
  const EnvironmentData({
    required this.currentTime,
    required this.season,
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.pressureChange12h,
  });

  /// 当前时间
  final DateTime currentTime;

  /// 季节
  final Season season;

  /// 温度（摄氏度）
  final double temperature;

  /// 湿度（百分比）
  final double humidity;

  /// 当前气压（hPa）
  final double pressure;

  /// 12小时内气压变化（hPa）
  final double pressureChange12h;

  /// 从JSON构造
  factory EnvironmentData.fromJson(Map<String, dynamic> json) {
    return EnvironmentData(
      currentTime: DateTime.parse(json['currentTime'] as String),
      season: Season.fromString(json['season'] as String?) ?? Season.spring,
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      pressure: (json['pressure'] as num).toDouble(),
      pressureChange12h: (json['pressureChange12h'] as num).toDouble(),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'currentTime': currentTime.toIso8601String(),
      'season': season.toValue(),
      'temperature': temperature,
      'humidity': humidity,
      'pressure': pressure,
      'pressureChange12h': pressureChange12h,
    };
  }
}
