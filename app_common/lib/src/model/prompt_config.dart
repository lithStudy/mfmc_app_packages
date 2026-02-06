/// 提示词配置模型
class PromptConfig {
  final Map<String, PromptTemplate> prompts;

  PromptConfig({required this.prompts});

  factory PromptConfig.fromJson(Map<String, dynamic> json) {
    final promptsMap = <String, PromptTemplate>{};
    final promptsJson = json['prompts'] as Map<String, dynamic>?;

    if (promptsJson != null) {
      promptsJson.forEach((key, value) {
        promptsMap[key] = PromptTemplate.fromJson(
          value as Map<String, dynamic>,
        );
      });
    }

    return PromptConfig(prompts: promptsMap);
  }

  Map<String, dynamic> toJson() {
    final promptsJson = <String, dynamic>{};
    prompts.forEach((key, value) {
      promptsJson[key] = value.toJson();
    });

    return {'prompts': promptsJson};
  }

  /// 获取指定类型的提示词模板
  PromptTemplate? getPrompt(String type) {
    return prompts[type];
  }
}

/// 提示词模板
class PromptTemplate {
  final String template;

  PromptTemplate({required this.template});

  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    return PromptTemplate(template: json['template'] as String? ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'template': template};
  }

  /// 渲染模板（简单的变量替换）
  String render(Map<String, dynamic> variables) {
    String result = template;

    variables.forEach((key, value) {
      if (value != null) {
        // 处理条件语句 {{#if key}}...{{/if}}
        final ifPattern = RegExp(
          '\\{\\{#if $key\\}\\}(.*?)\\{\\{/if\\}\\}',
          dotAll: true,
        );
        result = result.replaceAll(ifPattern, '\$1');

        // 替换变量 {{key}}
        result = result.replaceAll('{{$key}}', value.toString());
      } else {
        // 移除条件语句块
        final ifPattern = RegExp(
          '\\{\\{#if $key\\}\\}(.*?)\\{\\{/if\\}\\}',
          dotAll: true,
        );
        result = result.replaceAll(ifPattern, '');
      }
    });

    // 清理未匹配的条件语句
    result = result.replaceAll(
      RegExp(r'\{\{#if \w+\}\}.*?\{\{/if\}\}', dotAll: true),
      '',
    );

    // 处理 {{#each}} 循环
    final eachPattern = RegExp(
      r'\{\{#each (\w+)\}\}(.*?)\{\{/each\}\}',
      dotAll: true,
    );
    result = result.replaceAllMapped(eachPattern, (match) {
      final arrayKey = match.group(1)!;
      final itemTemplate = match.group(2)!;

      if (variables.containsKey(arrayKey) && variables[arrayKey] is List) {
        final items = variables[arrayKey] as List;
        return items
            .map((item) {
              String itemResult = itemTemplate;
              if (item is Map) {
                item.forEach((k, v) {
                  itemResult = itemResult.replaceAll(
                    '{{this.$k}}',
                    v.toString(),
                  );
                });
              } else {
                itemResult = itemResult.replaceAll('{{this}}', item.toString());
              }
              return itemResult;
            })
            .join('\n');
      }
      return '';
    });

    return result.trim();
  }
}
