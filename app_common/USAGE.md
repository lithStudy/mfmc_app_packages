# app_common 使用指南

## 概述

`app_common` 是 VitalLink 和 daily-notes 项目共享的通用模块包，包含：

- **AI 服务层**：支持多种 AI 提供商（百炼、Gemini、智普、豆包）
- **激活服务**：用户等级管理和邀请码验证
- **HTTP 服务**：统一的 HTTP 客户端工厂
- **工具类**：日志、时间处理、错误格式化等

## 依赖配置

在项目的 `pubspec.yaml` 中添加：

```yaml
dependencies:
  app_common:
    path: ../mfmc_app_packages/app_common
```

## 使用示例

### 1. 实现存储接口

激活服务需要实现 `ActivationStorage` 和 `AppConfigProvider` 接口：

```dart
import 'package:app_common/app_common.dart';

// 实现激活存储接口
class SettingsActivationStorage implements ActivationStorage {
  SettingsActivationStorage(this._settings);
  final SettingsRepository _settings;

  @override
  Future<String?> getTier() => _settings.getString('activation_tier');
  
  @override
  Future<void> setTier(String tier) => _settings.setString('activation_tier', tier);
  
  // ... 实现其他方法
}

// 实现配置提供者接口
class AppConfigProviderImpl implements AppConfigProvider {
  AppConfigProviderImpl(this._config);
  final AppConfig _config;

  @override
  String get backendUrl => _config.backendUrl;
  
  @override
  String get invitePublicKey => _config.invitePublicKey;
}
```

### 2. 实现客户端ID存储

HTTP 服务需要实现 `ClientIdStorage` 接口：

```dart
class SettingsClientIdStorage implements ClientIdStorage {
  SettingsClientIdStorage(this._settings);
  final SettingsRepository _settings;

  @override
  Future<String?> getClientId() => _settings.getString('client_id');
  
  @override
  Future<void> setClientId(String clientId) => 
      _settings.setString('client_id', clientId);
}
```

### 3. 初始化

在应用启动时初始化：

```dart
// 加载应用配置
final configLoader = AppConfigLoader();
final config = await configLoader.load();

// 初始化 HTTP 客户端工厂
await HttpClientFactory.initialize(SettingsClientIdStorage(settings));

// 初始化日志服务
await AppLogger.initialize();

// 创建激活服务
final activationService = ActivationService(
  SettingsActivationStorage(settings),
  AppConfigProviderImpl(config),
);
```

在项目中定义 Riverpod Provider（如需要）：

```dart
import 'package:app_common/app_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigLoaderProvider = Provider<AppConfigLoader>((ref) {
  return AppConfigLoader();
});

final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  final loader = ref.watch(appConfigLoaderProvider);
  return loader.load();
});
```

### 4. 使用录音服务

```dart
import 'package:app_common/app_common.dart';

// 创建录音器
final recorder = AudioRecorderFactory.create();

// 开始录音
await recorder.startRecording();

// 停止录音并获取数据
final audioBytes = await recorder.stopRecording();

// 释放资源
await recorder.dispose();
```

### 5. 使用 AI 服务

```dart
// 创建 AI 服务实例
final aiService = BailianAiService(
  apiKey: 'your-api-key',
  backendUrl: 'https://your-backend.com',
  model: 'qwen-plus',
);

// 调用 AI 接口
final result = await aiService.generateText(prompt: 'Hello');
```

## 模块说明

### 配置加载 (`src/config/`)

| 文件 | 说明 |
|------|------|
| `app_config.dart` | 应用配置数据模型 |
| `app_config_loader.dart` | 配置加载器（自动区分 dev/prod） |

### 录音服务 (`src/recording/`)

| 文件 | 说明 |
|------|------|
| `audio_recorder.dart` | 录音抽象接口和模型 |
| `audio_recorder_factory.dart` | 录音器工厂 |
| `mobile_audio_recorder.dart` | 移动端实现 |

### AI 服务 (`src/ai/`)

| 文件 | 说明 |
|------|------|
| `ai_service.dart` | AI 服务抽象接口 |
| `ai_provider_meta.dart` | AI 提供商元数据 |
| `openai_compatible_ai_service.dart` | OpenAI 兼容服务基类 |
| `bailian_ai_service.dart` | 百炼实现 |
| `gemini_ai_service.dart` | Gemini 实现 |
| `zhipu_ai_service.dart` | 智普实现 |
| `doubao_ai_service.dart` | 豆包实现 |
| `backend_ai_service.dart` | 后端代理服务 |

### 激活服务 (`src/activation/`)

| 文件 | 说明 |
|------|------|
| `activation_models.dart` | 激活相关数据模型 |
| `activation_storage.dart` | 存储接口定义 |
| `activation_service.dart` | 激活服务主类 |
| `crypto_service.dart` | 邀请码签名验证 |

### HTTP 服务 (`src/http/`)

| 文件 | 说明 |
|------|------|
| `http_client_factory.dart` | Dio 客户端工厂 |
| `client_id_interceptor.dart` | 客户端ID拦截器 |

### 工具类 (`src/util/`)

| 文件 | 说明 |
|------|------|
| `app_logger.dart` | 全局日志工具 |
| `logger_service.dart` | 日志服务实现 |
| `client_id_service.dart` | 客户端ID管理 |
| `json_utils.dart` | JSON 安全解析 |
| `time_util.dart` | 时间工具 |
| `time_extractor.dart` | 时间提取器 |
| `error_util.dart` | 错误格式化 |
