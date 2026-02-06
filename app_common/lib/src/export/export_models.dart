/// 导出流水线使用的 DTO，与各 app 的 domain 模型解耦。

/// 单条记录（用于导出）
class ExportEntry {
  const ExportEntry({
    required this.id,
    required this.personId,
    required this.type,
    required this.occurredAtIso,
    required this.textRaw,
    this.title,
    this.updatedAt,
  });

  final String id;
  final String personId;
  final String type;
  final String occurredAtIso;
  final String textRaw;
  final String? title;
  final String? updatedAt;
}

/// 单条附件（用于导出）
class ExportAttachment {
  const ExportAttachment({
    required this.id,
    required this.entryId,
    required this.filePath,
    required this.mimeType,
  });

  final String id;
  final String entryId;
  final String filePath;
  final String mimeType;
}
