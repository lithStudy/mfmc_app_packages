/// 通用模块包
/// 包含 VitalLink 和 daily-notes 共享的通用功能
library app_common;

// 配置加载
export 'src/config/app_config.dart';
export 'src/config/app_config_loader.dart';

// 模型
export 'src/model/ai_task_type.dart';
export 'src/model/prompt_config.dart';
export 'src/model/environment_data.dart';
export 'src/model/symptom_question_group.dart';

// AI 服务
export 'src/ai/ai_service.dart';
export 'src/ai/ai_provider_meta.dart';
export 'src/ai/backend_ai_service.dart';
export 'src/ai/bailian_ai_service.dart';
export 'src/ai/gemini_ai_service.dart';
export 'src/ai/zhipu_ai_service.dart';
export 'src/ai/doubao_ai_service.dart';
export 'src/ai/openai_compatible_ai_service.dart';
export 'src/ai/openai_adapter.dart';

// 激活服务
export 'src/activation/activation_models.dart';
export 'src/activation/activation_storage.dart';
export 'src/activation/activation_service.dart';
export 'src/activation/crypto_service.dart';

// 录音服务
export 'src/recording/audio_recorder.dart';
export 'src/recording/audio_recorder_factory.dart';
export 'src/recording/mobile_audio_recorder.dart';

// HTTP 服务
export 'src/http/http_client_factory.dart';
export 'src/http/client_id_interceptor.dart';

// 导出（Markdown 导出）
export 'src/export/export_models.dart';
export 'src/export/export_data_source.dart';
export 'src/export/export_file_ops.dart';
export 'src/export/markdown_export_runner.dart';

// 工具类
export 'src/util/client_id_service.dart';
export 'src/util/json_utils.dart';
export 'src/util/app_logger.dart';
export 'src/util/logger_service.dart';
export 'src/util/time_util.dart';
export 'src/util/time_extractor.dart';
export 'src/util/time_option_helper.dart';
export 'src/util/error_util.dart';
