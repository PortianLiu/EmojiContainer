/// 待导出到 Camera 的单张表情
class EmojiExportItem {
  const EmojiExportItem({
    required this.sourcePath,
    required this.albumName,
  });

  final String sourcePath;
  final String albumName;
}
