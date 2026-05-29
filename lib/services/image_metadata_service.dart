import 'dart:io';

import 'package:exif/exif.dart';

/// 从图片读取拍摄/修改时间，用于导入后设置文件时间戳。
class ImageMetadataService {
  /// 优先 EXIF 拍摄时间，其次源文件 [lastModified]。
  Future<DateTime?> resolveTimestamp(File source) async {
    final fromExif = await readCapturedAt(source);
    if (fromExif != null) return fromExif;
    try {
      return await source.lastModified();
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> readCapturedAt(File file) async {
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length < 32) return null;
      final data = await readExifFromBytes(bytes);
      if (data.isEmpty) return null;

      const keys = [
        'EXIF DateTimeOriginal',
        'EXIF DateTimeDigitized',
        'Image DateTime',
      ];
      for (final key in keys) {
        final tag = data[key];
        if (tag == null) continue;
        final parsed = _parseExifDate(tag.printable);
        if (parsed != null) return parsed;
      }
    } catch (_) {}
    return null;
  }

  /// 二进制写入目标文件并尽量保留原字节（JPEG 内嵌 EXIF 会一并保留）。
  Future<void> writePreservingBytes({
    required File source,
    required String destPath,
  }) async {
    final bytes = await source.readAsBytes();
    final out = File(destPath);
    await out.writeAsBytes(bytes, flush: true);
    final when = await resolveTimestamp(source);
    if (when != null) {
      try {
        await out.setLastModified(when);
      } catch (_) {}
    }
  }

  DateTime? _parseExifDate(String raw) {
    final s = raw.trim();
    if (s.length < 19) return null;
    try {
      final space = s.indexOf(' ');
      if (space < 0) return null;
      final date = s.substring(0, space).replaceAll(':', '-');
      final time = s.substring(space + 1);
      return DateTime.parse('$date $time');
    } catch (_) {
      return null;
    }
  }
}
