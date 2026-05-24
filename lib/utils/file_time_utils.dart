import 'dart:io';

import '../models/emoji_album.dart';

/// 同步读取修改时间（扫描时比 async 快很多）
int fileModifiedMillisSync(String path) {
  try {
    return File(path).lastModifiedSync().millisecondsSinceEpoch;
  } catch (_) {
    return 0;
  }
}

int directoryModifiedMillisSync(String path) {
  try {
    return FileStat.statSync(path).modified.millisecondsSinceEpoch;
  } catch (_) {
    return 0;
  }
}

/// 表情包夹默认排序键：直接子图片中最新的修改时间；无图时用目录修改时间
int albumSortMillis(EmojiAlbum album) {
  var latest = directoryModifiedMillisSync(album.path);
  for (final path in album.emojiPaths) {
    final t = fileModifiedMillisSync(path);
    if (t > latest) latest = t;
  }
  return latest;
}

/// 按修改时间逆序（新的在前）
void sortPathsByTimeDescSync(List<String> paths) {
  paths.sort(
    (a, b) =>
        fileModifiedMillisSync(b).compareTo(fileModifiedMillisSync(a)),
  );
}

void sortAlbumsByActivityDesc(List<EmojiAlbum> albums) {
  albums.sort(
    (a, b) => albumSortMillis(b).compareTo(albumSortMillis(a)),
  );
}
