import 'dart:io';

/// 一个表情包集（对应根目录下的一个子文件夹）
class EmojiAlbum {
  const EmojiAlbum({
    required this.name,
    required this.path,
    required this.emojiPaths,
    this.coverPath,
  });

  final String name;
  final String path;
  final List<String> emojiPaths;
  final String? coverPath;

  int get count => emojiPaths.length;

  /// 用于封面展示的图片路径
  String? get displayCover => coverPath ?? (emojiPaths.isNotEmpty ? emojiPaths.first : null);
}
