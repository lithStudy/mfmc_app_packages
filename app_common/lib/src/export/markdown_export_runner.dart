import 'package:path/path.dart' as p;

import '../util/time_util.dart';
import 'export_data_source.dart';
import 'export_file_ops.dart';
import 'export_models.dart';

/// 导出模式：增量（仅导出上次导出后更新的）或全量覆盖。
enum ExportMode { incremental, full }

/// Markdown 导出执行器，仅依赖 [ExportDataSource] 与 [ExportFileOps]。
class MarkdownExportRunner {
  MarkdownExportRunner({
    required this.dataSource,
    required this.fileOps,
    required this.exportDir,
    required this.personId,
    required this.mode,
    this.onProgress,
  });

  final ExportDataSource dataSource;
  final ExportFileOps fileOps;
  final String exportDir;
  final String personId;
  final ExportMode mode;
  final void Function(int current, int total)? onProgress;

  /// 执行导出。同一天的记录合并到同一 md 文件，文件名为日期（如 2025-02-06.md）。成功后更新 [ExportDataSource.setLastExportAt]。
  Future<void> run() async {
    List<ExportEntry> entries;
    if (mode == ExportMode.full) {
      entries = await dataSource.getEntriesToExport(personId, limit: 10000);
    } else {
      final last = await dataSource.getLastExportAt();
      entries = await dataSource.getEntriesToExport(
        personId,
        updatedAfterIso: last,
        limit: 5000,
      );
    }

    final total = entries.length;
    if (total == 0) return;

    final byDate = <String, List<ExportEntry>>{};
    for (final e in entries) {
      final date = _dateFromIso(e.occurredAtIso);
      byDate.putIfAbsent(date, () => []).add(e);
    }
    final dates = byDate.keys.toList()..sort();

    var current = 0;
    for (final date in dates) {
      final dayEntries = byDate[date]!
        ..sort((a, b) => a.occurredAtIso.compareTo(b.occurredAtIso));

      final sb = StringBuffer();
      sb.writeln('# $date');
      for (final entry in dayEntries) {
        final attachments = await dataSource.getAttachments(entry.id);
        sb.writeln();
        sb.writeln('---');
        sb.writeln();
        sb.write(_buildEntrySection(entry, attachments));
      }

      final mdPath = p.join(exportDir, '$date.md');
      await fileOps.writeTextFile(mdPath, sb.toString());

      for (final entry in dayEntries) {
        await _copyAttachments(entry);
        current++;
        onProgress?.call(current, total);
      }
    }

    await dataSource.setLastExportAt(nowIso());
  }

  /// 从 ISO 时间取日期部分 YYYY-MM-DD
  String _dateFromIso(String occurredAtIso) {
    if (occurredAtIso.length >= 10) return occurredAtIso.substring(0, 10);
    return occurredAtIso;
  }

  Future<void> _copyAttachments(ExportEntry entry) async {
    final attachments = await dataSource.getAttachments(entry.id);
    final attachmentsDir = p.join(exportDir, 'attachments', entry.id);
    for (final att in attachments) {
      final sourcePath = await dataSource.getAttachmentFilePath(att.filePath);
      if (sourcePath != null && sourcePath.isNotEmpty) {
        final destPath = p.join(attachmentsDir, p.basename(att.filePath));
        await fileOps.copyFile(sourcePath, destPath);
      } else {
        final bytes = await dataSource.getAttachmentBytes(att.filePath);
        if (bytes != null && bytes.isNotEmpty) {
          final destPath = p.join(attachmentsDir, p.basename(att.filePath));
          await fileOps.writeFileFromBytes(destPath, bytes);
        }
      }
    }
  }

  /// 单条记录在“按日合并”中的一节（时间 + 标题 + 正文 + 附件）
  String _buildEntrySection(
    ExportEntry entry,
    List<ExportAttachment> attachments,
  ) {
    final sb = StringBuffer();
    final timeLabel = _formatTimeLabel(entry.occurredAtIso);
    if (entry.title != null && entry.title!.isNotEmpty) {
      sb.writeln('## $timeLabel ${entry.title}');
    } else {
      sb.writeln('## $timeLabel');
    }
    sb.writeln();
    sb.writeln('**时间** ${entry.occurredAtIso}');
    sb.writeln();
    sb.writeln(entry.textRaw);

    if (attachments.isNotEmpty) {
      sb.writeln();
      sb.writeln('### 附件');
      for (final att in attachments) {
        final relPath = p.join(
          'attachments',
          entry.id,
          p.basename(att.filePath),
        );
        final isImage = att.mimeType.startsWith('image/');
        final name = p.basename(att.filePath);
        if (isImage) {
          sb.writeln('![$name]($relPath)');
        } else {
          sb.writeln('[$name]($relPath)');
        }
      }
    }
    return sb.toString();
  }

  String _formatTimeLabel(String occurredAtIso) {
    if (occurredAtIso.length >= 16) {
      return occurredAtIso.substring(11, 16);
    }
    if (occurredAtIso.length > 10) return occurredAtIso.substring(11);
    return occurredAtIso;
  }
}
