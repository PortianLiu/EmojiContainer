/// 一个表情包集（对应磁盘上的一个文件夹）
class EmojiAlbum {
  const EmojiAlbum({
    required this.name,
    required this.path,
    required this.emojiPaths,
    this.coverPath,
    this.subAlbums = const [],
    this.imageCount,
  });

  final String name;
  final String path;
  /// 列表/封面用路径；详情页在嵌套模式下可能只含当前层图片
  final List<String> emojiPaths;
  final String? coverPath;
  /// 嵌套模式下当前文件夹下的子表情包夹
  final List<EmojiAlbum> subAlbums;
  /// 平铺模式下统计的含子目录图片总数；为空时用 emojiPaths.length
  final int? imageCount;

  int get count => imageCount ?? emojiPaths.length;

  String? get displayCover =>
      coverPath ?? (emojiPaths.isNotEmpty ? emojiPaths.first : null);
}

/// 首页分组：name 为分组名，null 表示未分组；id 仅手动分组有值
class EmojiAlbumGroup {
  const EmojiAlbumGroup({
    this.id,
    required this.name,
    required this.albums,
  });

  final String? id;
  final String? name;
  final List<EmojiAlbum> albums;
}

/// 文件夹详情：当前层图片 + 嵌套子夹
class EmojiAlbumContents {
  const EmojiAlbumContents({
    required this.name,
    required this.path,
    required this.emojiPaths,
    this.subAlbums = const [],
    this.imageCount,
  });

  final String name;
  final String path;
  final List<String> emojiPaths;
  final List<EmojiAlbum> subAlbums;
  final int? imageCount;

  int get count => imageCount ?? emojiPaths.length;

  EmojiAlbum toAlbum() => EmojiAlbum(
        name: name,
        path: path,
        emojiPaths: emojiPaths,
        coverPath: emojiPaths.isNotEmpty ? emojiPaths.first : null,
        subAlbums: subAlbums,
        imageCount: imageCount,
      );
}
