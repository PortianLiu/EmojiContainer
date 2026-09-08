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

/// 路径 → mtime，每个 path 只 stat 一次
Map<String, int> buildFileMtimeCache(Iterable<String> paths) {
  final cache = <String, int>{};
  for (final path in paths) {
    cache[path] = fileModifiedMillisSync(path);
  }
  return cache;
}

Map<String, int> buildDirectoryMtimeCache(Iterable<String> paths) {
  final cache = <String, int>{};
  for (final path in paths) {
    cache[path] = directoryModifiedMillisSync(path);
  }
  return cache;
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

/// 按修改时间逆序（新的在前）；比较器内只查表，避免重复 lastModifiedSync
void sortPathsByTimeDescSync(List<String> paths) {
  if (paths.length <= 1) return;
  final mtimes = buildFileMtimeCache(paths);
  paths.sort((a, b) => (mtimes[b] ?? 0).compareTo(mtimes[a] ?? 0));
}

void sortAlbumsByActivityDesc(List<EmojiAlbum> albums) {
  if (albums.length <= 1) return;
  final keys = <String, int>{};
  for (final album in albums) {
    keys[album.path] = albumSortMillis(album);
  }
  albums.sort((a, b) => (keys[b.path] ?? 0).compareTo(keys[a.path] ?? 0));
}

void sortDirectoriesByMtimeDescSync(List<Directory> dirs) {
  if (dirs.length <= 1) return;
  final mtimes = buildDirectoryMtimeCache(dirs.map((d) => d.path));
  dirs.sort(
    (a, b) => (mtimes[b.path] ?? 0).compareTo(mtimes[a.path] ?? 0),
  );
}
