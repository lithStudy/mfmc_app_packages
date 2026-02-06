/// 导出时的文件操作接口，由各 app 实现（写 MD、复制附件到导出目录，或写入 ZIP 等）。
abstract class ExportFileOps {
  /// 在导出目录下写入文本文件。[path] 为相对导出根目录的路径或实现方约定的路径。
  Future<void> writeTextFile(String path, String content);

  /// 将 [sourcePath] 复制到导出目录下的 [destPath]。[destPath] 可为相对路径，由实现方拼接到导出根目录。
  Future<void> copyFile(String sourcePath, String destPath);

  /// 将字节内容写入 [path]（用于 Web 等无源文件路径时，由 DataSource.getAttachmentBytes 提供内容）。
  /// 默认抛出 UnsupportedError；ZIP 等实现需重写。
  Future<void> writeFileFromBytes(String path, List<int> bytes) async {
    throw UnsupportedError('writeFileFromBytes not supported');
  }
}
