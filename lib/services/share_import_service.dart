import 'dart:io';

import 'package:path/path.dart' as p;

import 'emoji_constants.dart';
import 'image_metadata_service.dart';

class ShareImportResult {
  const ShareImportResult({required this.importedCount});

  final int importedCount;
}

class ShareImportService {
  ShareImportService({ImageMetadataService? metadata})
      : _metadata = metadata ?? ImageMetadataService();

  final ImageMetadataService _metadata;

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
    final srcFile = await _openSource(source);
    if (srcFile == null) {
      throw ShareImportException('无法读取分享的图片');
    }

    final fileName = _resolveFileName(source, srcFile.path);
    final dest = await _uniqueDestPath(albumPath, fileName);

    await _metadata.writePreservingBytes(source: srcFile, destPath: dest);

    final out = File(dest);
    if (!await out.exists() || await out.length() <= 0) {
      try {
        if (await out.exists()) await out.delete();
      } catch (_) {}
      return false;
    }

    return true;
  }

  /// 分享插件会把内容复制到临时文件；少数机型仍可能是 content URI。
  Future<File?> _openSource(String source) async {
    final direct = File(source);
    if (await direct.exists()) return direct;

    if (source.startsWith('content://')) {
      return null;
    }

    final stripped = source.replaceFirst('file://', '');
    final file = File(stripped);
    if (await file.exists()) return file;
    return null;
  }

  String _resolveFileName(String source, String resolvedPath) {
    var name = p.basename(source.split('?').first);
    if (name.isEmpty || name == '/' || !name.contains('.')) {
      name = p.basename(resolvedPath);
    }
    if (name.isEmpty || name == '/') {
      name = 'shared_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    if (p.extension(name).isEmpty) {
      name = '$name.jpg';
    }
    if (!isImageFile(name)) {
      final ext = p.extension(resolvedPath);
      if (ext.isNotEmpty) name = '${p.basenameWithoutExtension(name)}$ext';
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
