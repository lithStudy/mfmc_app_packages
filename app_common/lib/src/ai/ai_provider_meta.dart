/// AI服务商配置元数据
class AiProviderMeta {
  const AiProviderMeta({
    required this.id,
    required this.name,
    required this.apiKeyHint,
    required this.defaultModel,
    required this.defaultVisionModel,
    required this.defaultAudioModel,
    required this.defaultEndpoint,
    required this.endpointHint,
  });

  /// 服务商ID：'bailian', 'gemini', 'zhipu', 'doubao'
  final String id;

  /// 显示名称
  final String name;

  /// API Key输入提示
  final String apiKeyHint;

  /// 默认文本模型
  final String defaultModel;

  /// 默认视觉模型
  final String defaultVisionModel;

  /// 默认语音模型
  final String defaultAudioModel;

  /// 默认API端点
  final String defaultEndpoint;

  /// Endpoint输入提示
  final String endpointHint;

  /// 所有支持的服务商元数据
  static const Map<String, AiProviderMeta> providers = {
    'bailian': AiProviderMeta(
      id: 'bailian',
      name: '阿里云百炼',
      apiKeyHint: 'sk-xxx',
      defaultModel: 'qwen-plus',
      defaultVisionModel: 'qwen-vl-max',
      defaultAudioModel: 'qwen3-asr-flash',
      defaultEndpoint:
          'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
      endpointHint:
          'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
    ),
    'gemini': AiProviderMeta(
      id: 'gemini',
      name: 'Google Gemini',
      apiKeyHint: 'AIza...',
      defaultModel: 'gemini-pro',
      defaultVisionModel: 'gemini-1.5-flash',
      defaultAudioModel: 'gemini-1.5-flash',
      defaultEndpoint:
          'https://generativelanguage.googleapis.com/v1beta/models',
      endpointHint: 'https://generativelanguage.googleapis.com/v1beta/models',
    ),
    'zhipu': AiProviderMeta(
      id: 'zhipu',
      name: '智普AI',
      apiKeyHint: 'xxx.xxx',
      defaultModel: 'glm-4.7',
      defaultVisionModel: 'glm-4.6v',
      defaultAudioModel: 'glm-asr-2512',
      defaultEndpoint: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      endpointHint: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    ),
    'doubao': AiProviderMeta(
      id: 'doubao',
      name: '豆包AI',
      apiKeyHint: 'sk-xxx',
      defaultModel: 'doubao-1.5-pro-32k',
      defaultVisionModel: 'doubao-1.5-vision-pro-32k',
      defaultAudioModel: 'doubao-asr-2.0',
      defaultEndpoint:
          'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
      endpointHint: 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
    ),
  };
}

/// 统一的AI服务配置值
class AiProviderConfigValue {
  const AiProviderConfigValue({
    required this.apiKey,
    this.endpoint,
    required this.model,
    required this.visionModel,
  });

  final String apiKey;
  final String? endpoint;
  final String model;
  final String visionModel;
}
