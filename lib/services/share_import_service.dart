import 'dart:io';

import 'package:path/path.dart' as p;

import 'emoji_constants.dart';

class ShareImportResult {
  const ShareImportResult({required this.importedCount});

  final int importedCount;
}

class ShareImportService {
  ShareImportService();

  Future<ShareImportResult> importPaths({
    required List<String> sourcePaths,
    required String albumPath,
  }) async {
    if (sourcePaths.isEmpty) {
      throw ShareImportException('没有可导入的图片');
    }

    final albumDir = Directory(albumPath);
    if (!await albumDir.exists()) {
      await albumDir.create(recursive: true);
    }

    var count = 0;
    Object? lastError;

    for (final source in sourcePaths) {
      try {
        if (await _importOne(source, albumPath)) count++;
      } catch (e) {
        lastError = e;
      }
    }

    if (count == 0) {
      throw ShareImportException(
        lastError != null ? '导入失败：$lastError' : '未能导入任何图片',
      );
    }

    return ShareImportResult(importedCount: count);
  }

  Future<bool> _importOne(String source, String albumPath) async {
    final fileName = _resolveFileName(source);
    final dest = await _uniqueDestPath(albumPath, fileName);
    final srcFile = File(source);

    if (await srcFile.exists()) {
      await srcFile.copy(dest);
    } else if (source.startsWith('content://')) {
      throw ShareImportException('无法读取分享的图片');
    } else {
      throw ShareImportException('文件不存在：$source');
    }

    final out = File(dest);
    if (!await out.exists() || await out.length() <= 0) {
      try {
        if (await out.exists()) await out.delete();
      } catch (_) {}
      return false;
    }

    try {
      final modified = await srcFile.lastModified();
      await out.setLastModified(modified);
    } catch (_) {}

    return true;
  }

  String _resolveFileName(String source) {
    var name = p.basename(source.split('?').first);
    if (name.isEmpty || name == '/') {
      name = 'shared_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    if (p.extension(name).isEmpty) {
      name = '$name.jpg';
    }
    if (!isImageFile(name)) {
      final ext = p.extension(name);
      if (ext.isEmpty) name = '$name.jpg';
    }
    return name;
  }

  Future<String> _uniqueDestPath(String dir, String fileName) async {
    var dest = p.join(dir, fileName);
    if (!await File(dest).exists()) return dest;

    final ext = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    var n = 1;
    while (await File(dest).exists()) {
      dest = p.join(dir, '${base}_$n$ext');
      n++;
    }
    return dest;
  }
}

class ShareImportException implements Exception {
  ShareImportException(this.message);
  final String message;

  @override
  String toString() => message;
}
