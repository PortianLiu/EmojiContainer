import 'dart:io';

import 'package:path/path.dart' as p;

import 'emoji_constants.dart';
import 'emoji_repository.dart';

/// 为有图片的文件夹创建 .nomedia（仅 Android 生效）
class NomediaService {
  static const skipDirNames = EmojiRepository.skipDirNames;

  Future<int> ensureNomediaUnder(String rootPath) async {
    if (!Platform.isAndroid) return 0;
    final root = Directory(rootPath);
    if (!await root.exists()) return 0;
    return _visit(root);
  }

  Future<int> ensureNomediaForDirectory(String dirPath) async {
    if (!Platform.isAndroid) return 0;
    final dir = Directory(dirPath);
    if (!await dir.exists()) return 0;
    var created = 0;
    if (await _ensureOne(dir)) created++;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory && !_shouldSkip(_folderName(entity.path))) {
        created += await _visit(entity);
      }
    }
    return created;
  }

  Future<int> _visit(Directory dir) async {
    var created = 0;
    if (await _hasDirectImages(dir)) {
      if (await _ensureOne(dir)) created++;
    }
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory && !_shouldSkip(_folderName(entity.path))) {
        created += await _visit(entity);
      }
    }
    return created;
  }

  Future<bool> _ensureOne(Directory dir) async {
    final file = File(p.join(dir.path, '.nomedia'));
    if (await file.exists()) return false;
    await file.create(recursive: false);
    return true;
  }

  Future<bool> _hasDirectImages(Directory dir) async {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && isImageFile(entity.path)) return true;
    }
    return false;
  }

  bool _shouldSkip(String name) =>
      name.startsWith('.') || skipDirNames.contains(name);

  String _folderName(String path) {
    final sep = Platform.pathSeparator;
    if (path.endsWith(sep)) {
      path = path.substring(0, path.length - 1);
    }
    final i = path.lastIndexOf(sep);
    return i < 0 ? path : path.substring(i + 1);
  }
}
