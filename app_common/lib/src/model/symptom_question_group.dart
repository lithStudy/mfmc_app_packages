/// 症状选项
class SymptomOption {
  const SymptomOption({
    required this.text,
    this.childOptions,
    this.timePreset,
    this.showDatePicker = false,
  });

  /// 选项文本
  final String text;

  /// 子选项列表（可选，用于嵌套选项如"湿咳"下的痰色选择）
  final List<SymptomOption>? childOptions;

  /// 时间预设：如 "now", "-3h", "-1d", "-3d" 等
  final String? timePreset;

  /// 是否显示日期选择器
  final bool showDatePicker;

  /// 是否为时间选项
  bool get isTimeOption => timePreset != null || showDatePicker;

  /// 从JSON构造
  factory SymptomOption.fromJson(Map<String, dynamic> json) {
    return SymptomOption(
      text: json['text'] as String,
      childOptions: json['childOptions'] != null
          ? (json['childOptions'] as List)
                .map((e) => SymptomOption.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      timePreset: json['timePreset'] as String?,
      showDatePicker: json['showDatePicker'] as bool? ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (childOptions != null)
        'childOptions': childOptions!.map((e) => e.toJson()).toList(),
      if (timePreset != null) 'timePreset': timePreset,
      if (showDatePicker) 'showDatePicker': showDatePicker,
    };
  }
}

/// 症状追问问题组
class SymptomQuestionGroup {
  const SymptomQuestionGroup({
    required this.groupName,
    required this.options,
    this.allowMultiple = false,
    this.allowSkip = true,
    this.phase = 1,
    this.inputType,
    this.allowSupplementInput = false,
  });

  /// 分组名称（如"类型"、"程度"、"持续时间"等）
  final String groupName;

  /// 该分组下的选项列表
  final List<SymptomOption> options;

  /// 是否允许该分组内进行多选
  final bool allowMultiple;

  /// 是否允许跳过该分组
  final bool allowSkip;

  /// 问诊阶段：1=快速录入阶段（核心问题），2=详细追问阶段（AI补充）
  final int phase;

  /// 输入类型：null或"choice"表示选项选择，"datetime"表示时间选择器
  final String? inputType;

  /// 是否允许补充输入框
  final bool allowSupplementInput;

  /// 从JSON构造
  factory SymptomQuestionGroup.fromJson(Map<String, dynamic> json) {
    return SymptomQuestionGroup(
      groupName: json['groupName'] as String,
      options: (json['options'] as List)
          .map((e) => SymptomOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      allowMultiple: json['allowMultiple'] as bool? ?? false,
      allowSkip: json['allowSkip'] as bool? ?? true,
      phase: json['phase'] as int? ?? 1,
      inputType: json['inputType'] as String?,
      allowSupplementInput: json['allowSupplementInput'] as bool? ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'groupName': groupName,
      'options': options.map((e) => e.toJson()).toList(),
      'allowMultiple': allowMultiple,
      'allowSkip': allowSkip,
      'phase': phase,
      if (inputType != null) 'inputType': inputType,
      'allowSupplementInput': allowSupplementInput,
    };
  }
}
