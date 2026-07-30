/// 一个表情包集（对应磁盘上的一个文件夹）
class EmojiAlbum {
  const EmojiAlbum({
    required this.name,
    required this.path,
    required this.emojiPaths,
    this.coverPath,
    this.coverThumbs = const [],
    this.subAlbums = const [],
    this.imageCount,
  });

  final String name;
  final String path;
  /// 列表/封面用路径；详情页在嵌套模式下可能只含当前层图片
  final List<String> emojiPaths;
  final String? coverPath;
  /// 首页九宫格/单封面用的预计算缩略图路径（通常 ≤9，已按时间倒序）
  final List<String> coverThumbs;
  /// 嵌套模式下当前文件夹下的子表情包夹
  final List<EmojiAlbum> subAlbums;
  /// 平铺模式下统计的含子目录图片总数；为空时用 emojiPaths.length
  final int? imageCount;

  int get count => imageCount ?? emojiPaths.length;

  String? get displayCover =>
      coverPath ??
      (coverThumbs.isNotEmpty
          ? coverThumbs.first
          : (emojiPaths.isNotEmpty ? emojiPaths.first : null));

  EmojiAlbum copyWith({
    String? name,
    String? path,
    List<String>? emojiPaths,
    String? coverPath,
    List<String>? coverThumbs,
    List<EmojiAlbum>? subAlbums,
    int? imageCount,
    bool clearCoverPath = false,
  }) {
    return EmojiAlbum(
      name: name ?? this.name,
      path: path ?? this.path,
      emojiPaths: emojiPaths ?? this.emojiPaths,
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
      coverThumbs: coverThumbs ?? this.coverThumbs,
      subAlbums: subAlbums ?? this.subAlbums,
      imageCount: imageCount ?? this.imageCount,
    );
  }
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
        coverThumbs: emojiPaths.take(9).toList(),
        subAlbums: subAlbums,
        imageCount: imageCount,
      );
}
