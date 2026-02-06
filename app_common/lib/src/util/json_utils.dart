import 'dart:convert';

/// 安全解析JSON字符串，自动处理markdown代码块包裹的情况
///
/// 支持：
/// 1. 纯JSON字符串
/// 2. Markdown代码块包裹的JSON：```json ... ``` 或 ``` ... ```
/// 3. 文本中嵌入的JSON对象
///
/// 返回解析后的对象，解析失败返回null
dynamic parseJsonSafely(String? text) {
  if (text == null || text.isEmpty) return null;

  // 1. 先尝试直接解析
  try {
    return jsonDecode(text);
  } catch (_) {
    // 继续尝试提取
  }

  // 2. 尝试从文本中提取JSON
  final extracted = extractJsonFromText(text);
  if (extracted != null) {
    try {
      return jsonDecode(extracted);
    } catch (_) {
      // 提取的内容也无法解析
    }
  }

  return null;
}

/// 辅助工具：从原始文本中尽可能提取一段结构化JSON字符串
///
/// 支持如下场景：
/// 1. Markdown代码块包裹的json：```json ...``` 或 ``` ... ```
/// 2. 直接裸JSON：{ ... }
String? extractJsonFromText(String text) {
  if (text.isEmpty) return null;

  // 优先找markdown代码块包裹的json
  final codeBlockPattern = RegExp(r'```(?:json)?\s*\n?(.*?)```', dotAll: true);
  final codeBlockMatch = codeBlockPattern.firstMatch(text);
  if (codeBlockMatch != null) {
    final jsonInBlock = codeBlockMatch.group(1)?.trim();
    if (jsonInBlock != null && jsonInBlock.isNotEmpty) {
      // 尝试在代码块内容里再提一次{}
      final jsonFromBlock = extractJsonObject(jsonInBlock);
      if (jsonFromBlock != null) {
        return jsonFromBlock;
      }
      // 否则直接返回
      return jsonInBlock;
    }
  }

  // 无代码块时尝试裸json
  return extractJsonObject(text);
}

/// 辅助：在任意text中提取一段"完整且配对的"JSON对象字符串({ ... })，返回null表示未找到
String? extractJsonObject(String text) {
  if (text.isEmpty) return null;

  // 找第一个左大括号
  final firstBrace = text.indexOf('{');
  if (firstBrace == -1) return null;

  // 从此处开始遍历查找配对的右大括号
  int braceCount = 0;
  int lastBrace = -1;

  for (int i = firstBrace; i < text.length; i++) {
    if (text[i] == '{') {
      braceCount++;
    } else if (text[i] == '}') {
      braceCount--;
      if (braceCount == 0) {
        lastBrace = i;
        break;
      }
    }
  }

  if (lastBrace == -1) return null;

  // 截取完整的json
  final jsonText = text.substring(firstBrace, lastBrace + 1);
  return jsonText.trim();
}

/// 将任务或payload序列化为字符串，用作任务幂等性哈希
///
/// MVP阶段直接使用序列化JSON，后续可上crypto哈希优化
String hashPayload(Map<String, dynamic> payload) {
  // MVP：用稳定JSON字符串做hash输入，后续可替换为真正hash（crypto.sha256）。
  return jsonEncode(payload);
}

/// 解析异常标识字符串
String? parseAbnormalFlag(String? flag) {
  if (flag == null) return null;
  switch (flag.toLowerCase()) {
    case 'low':
    case 'l':
    case '偏低':
    case '降低':
    case '↓':
      return 'low';
    case 'high':
    case 'h':
    case '偏高':
    case '升高':
    case '↑':
      return 'high';
    case 'normal':
    case 'n':
    case '正常':
      return 'normal';
    default:
      return null;
  }
}
