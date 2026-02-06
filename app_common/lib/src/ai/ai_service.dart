/// 通用的AI服务接口
/// 所有AI服务提供商（代理、百炼、OpenAI等）都需要实现此接口
abstract class AiService {
  /// 通用文本生成接口
  /// [prompt] 提示词
  /// [options] 额外参数（如 temperature, maxTokens 等）
  Future<Map<String, dynamic>> generateText({
    required String prompt,
    Map<String, dynamic>? options,
  });

  /// 通用视觉识别接口
  /// [prompt] 提示词
  /// [imagePath] 图片路径
  /// [options] 额外参数
  Future<Map<String, dynamic>> generateTextWithImage({
    required String prompt,
    required String imagePath,
    Map<String, dynamic>? options,
  });

  /// 提取要点
  /// [prompt] 预先构建好的提示词
  Future<Map<String, dynamic>> extract({
    required String personId,
    required String prompt,
    required String inputHash,
  });

  /// 生成追问问题
  /// [prompt] 预先构建好的提示词
  Future<Map<String, dynamic>> questions({
    required String personId,
    required String prompt,
    required String inputHash,
  });

  /// 生成总结
  /// [prompt] 预先构建好的提示词
  Future<Map<String, dynamic>> summary({
    required String personId,
    required String prompt,
    required String inputHash,
  });

  /// 视觉识别（图片内容识别）
  /// [prompt] 预先构建好的提示词
  /// [imagePaths] 图片文件的完整路径列表（支持多图）
  Future<Map<String, dynamic>> visionRecognize({
    required String personId,
    required String prompt,
    required List<String> imagePaths,
    required String inputHash,
  });

  /// 生成标题
  /// [prompt] 预先构建好的提示词
  Future<Map<String, dynamic>> generateTitle({
    required String prompt,
    required String inputHash,
  });

  /// 检查报告OCR识别
  /// [prompt] 预先构建好的提示词
  /// [imagePath] 图片文件的完整路径
  Future<Map<String, dynamic>> examinationOcr({
    required String personId,
    required String prompt,
    required String imagePath,
    required String inputHash,
  });

  /// 检验报告OCR识别
  /// [prompt] 预先构建好的提示词
  /// [imagePath] 图片文件的完整路径
  Future<Map<String, dynamic>> labTestOcr({
    required String personId,
    required String prompt,
    required String imagePath,
    required String inputHash,
  });

  /// 音频转文字
  /// [prompt] 预先构建好的提示词
  /// [audioPath] 音频文件的完整路径
  Future<Map<String, dynamic>> audioTranscription({
    required String personId,
    required String prompt,
    required String audioPath,
    required String inputHash,
  });
}

/// AI服务提供商类型
enum AiProviderType {
  /// 直接对接阿里云百炼
  bailian,

  /// 直接对接Google Gemini
  gemini,

  /// 直接对接OpenAI（预留）
  openai,

  /// 直接对接智普AI
  zhipu,

  /// 直接对接豆包AI（字节跳动）
  doubao,
}

/// AI服务配置基类
abstract class AiServiceConfig {
  AiProviderType get type;
}

/// 百炼服务配置
class BailianAiServiceConfig extends AiServiceConfig {
  BailianAiServiceConfig({required this.apiKey, String? endpoint, this.model})
    : endpoint =
          endpoint ??
          'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation';

  final String apiKey;
  final String endpoint;
  final String? model;

  @override
  AiProviderType get type => AiProviderType.bailian;
}

/// Gemini服务配置
class GeminiAiServiceConfig extends AiServiceConfig {
  GeminiAiServiceConfig({required this.apiKey, this.model});

  final String apiKey;
  final String? model;

  @override
  AiProviderType get type => AiProviderType.gemini;
}

/// 智普服务配置
class ZhipuAiServiceConfig extends AiServiceConfig {
  ZhipuAiServiceConfig({required this.apiKey, String? endpoint, this.model})
    : endpoint =
          endpoint ?? 'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  final String apiKey;
  final String endpoint;
  final String? model;

  @override
  AiProviderType get type => AiProviderType.zhipu;
}

/// 豆包服务配置（字节跳动）
class DoubaoAiServiceConfig extends AiServiceConfig {
  DoubaoAiServiceConfig({required this.apiKey, String? endpoint, this.model})
    : endpoint =
          endpoint ??
          'https://ark.cn-beijing.volces.com/api/v3/chat/completions';

  final String apiKey;
  final String endpoint;
  final String? model;

  @override
  AiProviderType get type => AiProviderType.doubao;
}
