/// AI任务类型枚举
/// 与提示词配置中的键一一对应
enum AiTaskType {
  /// 标题生成（对应提示词：title）
  title('title_generation', 'title'),

  /// 结构化提取（对应提示词：extract）
  extraction('extraction', 'extract'),

  /// 追问生成（对应提示词：questions）
  questions('questions', 'questions'),

  /// Episode总结（对应提示词：episodeSummary）
  episodeSummary('episodeSummary', 'episodeSummary'),

  /// Episode标题生成（对应提示词：episodeTitle）
  episodeTitle('episodeTitle', 'episodeTitle'),

  /// 视觉识别（对应提示词：visionRecognize）
  visionRecognize('vision_recognize', 'visionRecognize'),

  /// 检验报告OCR（使用 visionRecognize 提示词）
  labTestOcr('lab_test_ocr', 'visionRecognize'),

  /// 检查报告OCR（使用 visionRecognize 提示词）
  examinationOcr('examination_ocr', 'visionRecognize'),

  /// 音频转文字（对应提示词：audioTranscription）
  audioTranscription('audio_transcription', 'audioTranscription'),

  /// 症状提取（对应提示词：symptomExtraction）
  symptomExtraction('symptom_extraction', 'symptomExtraction');

  /// 任务类型值（用于数据库存储和API）
  final String value;

  /// 对应的提示词键（用于从配置中加载提示词模板）
  final String promptKey;

  const AiTaskType(this.value, this.promptKey);

  /// 从字符串值创建枚举（用于从数据库读取）
  static AiTaskType? fromString(String? value) {
    if (value == null) return null;
    try {
      return AiTaskType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => throw ArgumentError('Unknown task type: $value'),
      );
    } catch (e) {
      return null;
    }
  }

  /// 从提示词键创建枚举
  static AiTaskType? fromPromptKey(String? promptKey) {
    if (promptKey == null) return null;
    try {
      return AiTaskType.values.firstWhere(
        (e) => e.promptKey == promptKey,
        orElse: () => throw ArgumentError('Unknown prompt key: $promptKey'),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() => value;
}
