import 'dart:typed_data';

import 'export_models.dart';

/// 导出数据源接口，由各 app 实现（对接 EntryRepository、AttachmentRepository、Settings 等）。
abstract class ExportDataSource {
  /// 获取待导出的条目列表。
  /// [updatedAfterIso] 非空时仅返回 updated_at > 该时间的条目（增量）；为空时返回全量，[limit] 生效。
  Future<List<ExportEntry>> getEntriesToExport(
    String personId, {
    String? updatedAfterIso,
    int? limit,
  });

  /// 获取指定条目的附件列表。
  Future<List<ExportAttachment>> getAttachments(String entryId);

  /// 解析附件相对路径为本地绝对路径；Web/base64 等无法解析时返回 null。
  Future<String?> getAttachmentFilePath(String relativePath);

  /// 获取附件内容为字节（用于 Web 等无文件路径场景，如 base64 存储）。无法提供时返回 null。
  Future<Uint8List?> getAttachmentBytes(String relativePath) async => null;

  /// 上次导出时间（ISO），用于增量导出。
  Future<String?> getLastExportAt();

  /// 保存上次导出时间。
  Future<void> setLastExportAt(String iso);
}
