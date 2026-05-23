import 'dart:io';

import '../models/emoji_album.dart';
import '../utils/file_time_utils.dart';
import 'emoji_constants.dart';

class EmojiRepository {
  static const skipDirNames = {'camera', '.emoji_container_exports'};

  /// 扫描根目录（列表页不排序每张图，仅按文件夹修改时间排序专辑）
  Future<List<EmojiAlbum>> loadAlbums(String rootPath) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      throw EmojiRepositoryException('目录不存在：$rootPath');
    }

    final albums = <EmojiAlbum>[];
    final rootName = _folderName(rootPath);

    final rootImages = await _collectImages(root, recursive: false);
    if (rootImages.isNotEmpty) {
      albums.add(_buildAlbum(rootName, rootPath, rootImages));
    }

    final subdirs = <Directory>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = _folderName(entity.path);
      if (name.startsWith('.') || skipDirNames.contains(name)) continue;
      subdirs.add(entity);
    }

    final subResults = await Future.wait(
      subdirs.map((dir) async {
        final emojiPaths = await _collectImages(dir, recursive: true);
        if (emojiPaths.isEmpty) return null;
        return _buildAlbum(_folderName(dir.path), dir.path, emojiPaths);
      }),
    );

    for (final album in subResults) {
      if (album != null) albums.add(album);
    }

    albums.sort(
      (a, b) => _directoryModifiedMillis(b.path)
          .compareTo(_directoryModifiedMillis(a.path)),
    );

    return albums;
  }

  EmojiAlbum _buildAlbum(String name, String path, List<String> emojiPaths) {
    return EmojiAlbum(
      name: name,
      path: path,
      emojiPaths: emojiPaths,
      coverPath: _pickNewestCover(emojiPaths),
    );
  }

  String? _pickNewestCover(List<String> paths) {
    if (paths.isEmpty) return null;
    var best = paths.first;
    var bestT = fileModifiedMillisSync(best);
    for (var i = 1; i < paths.length; i++) {
      final t = fileModifiedMillisSync(paths[i]);
      if (t > bestT) {
        bestT = t;
        best = paths[i];
      }
    }
    return best;
  }

  int _directoryModifiedMillis(String path) {
    try {
      return FileStat.statSync(path).modified.millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  Future<List<String>> _collectImages(
    Directory dir, {
    required bool recursive,
  }) async {
    final result = <String>[];
    await for (final entity in dir.list(
      recursive: recursive,
      followLinks: false,
    )) {
      if (entity is File && isImageFile(entity.path)) {
        result.add(entity.path);
      }
    }
    return result;
  }

  String _folderName(String path) {
    final sep = Platform.pathSeparator;
    if (path.endsWith(sep)) {
      path = path.substring(0, path.length - 1);
    }
    final i = path.lastIndexOf(sep);
    return i < 0 ? path : path.substring(i + 1);
  }
}

class EmojiRepositoryException implements Exception {
  EmojiRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
