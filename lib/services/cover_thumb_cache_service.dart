import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/emoji_album.dart';
import 'album_cover_service.dart';
import 'emoji_constants.dart';
import 'preferences_service.dart';

/// 封面缩略图磁盘缓存（约 240px），加快首屏绘制。
/// 不透明图用 JPEG；含透明通道的 PNG 用 PNG 缓存，避免白底。
/// GIF/WebP 动图不生成缓存，直接读原文件。
class CoverThumbCacheService {
  CoverThumbCacheService({AlbumCoverService? coverService})
      : _coverService = coverService ?? AlbumCoverService();

  final AlbumCoverService _coverService;
  static const _maxSide = 240;
  static const _jpegQuality = 85;
  static const _maxWarmImages = 48;
  static const _warmBatchSize = 2;
  static const _thumbSubdir = 'cover_thumbs';

  bool _warming = false;
  bool _legacyCleaned = false;

  /// 可再生的缩略图放在 cache 目录，系统可清理；列表 JSON 仍在 documents。
  Future<Directory> _thumbDir() async {
    if (!_legacyCleaned) {
      _legacyCleaned = true;
      await _removeLegacyDocumentsThumbDir();
    }
    final base = await getApplicationCacheDirectory();
    final dir = Directory(p.join(base.path, _thumbSubdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _removeLegacyDocumentsThumbDir() async {
    try {
      final doc = await getApplicationDocumentsDirectory();
      final legacy = Directory(p.join(doc.path, _thumbSubdir));
      if (await legacy.exists()) {
        await legacy.delete(recursive: true);
      }
    } catch (_) {}
  }

  String _fileName(String sourcePath, DateTime modified, {required bool png}) {
    final digest = sha1.convert(utf8.encode(sourcePath)).toString();
    final ext = png ? 'png' : 'jpg';
    return '${digest}_${modified.millisecondsSinceEpoch}.$ext';
  }

  /// 缓存有效条件：存在与源文件 **lastModified** 匹配的缩略图文件。
  Future<String?> cachedThumbPath(String sourcePath) async {
    if (shouldSkipCoverThumbCache(sourcePath)) return null;

    final src = File(sourcePath);
    if (!await src.exists()) return null;
    DateTime modified;
    try {
      modified = await src.lastModified();
    } catch (_) {
      return null;
    }

    final dir = await _thumbDir();
    for (final ext in ['jpg', 'png']) {
      final file = File(
        p.join(dir.path, _fileName(sourcePath, modified, png: ext == 'png')),
      );
      if (await file.exists()) return file.path;
    }
    return null;
  }

  Future<String?> ensureThumb(String sourcePath) async {
    if (shouldSkipCoverThumbCache(sourcePath)) return null;

    final hit = await cachedThumbPath(sourcePath);
    if (hit != null) return hit;

    final src = File(sourcePath);
    if (!await src.exists()) return null;

    DateTime modified;
    try {
      modified = await src.lastModified();
    } catch (_) {
      return null;
    }

    try {
      final result = await compute(
        _generateThumbIsolate,
        _ThumbJob(sourcePath: sourcePath, maxSide: _maxSide, quality: _jpegQuality),
      );
      if (result == null) return null;

      final outPath = p.join(
        (await _thumbDir()).path,
        _fileName(sourcePath, modified, png: result.usePng),
      );
      await File(outPath).writeAsBytes(result.bytes);
      await _purgeStaleForSource(sourcePath, keep: outPath);
      return outPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> warmAlbums(
    List<EmojiAlbum> albums, {
    required AlbumCoverStyle coverStyle,
  }) async {
    if (_warming || albums.isEmpty) return;
    _warming = true;

    try {
      final paths = <String>{};
      for (final album in albums.take(32)) {
        if (coverStyle == AlbumCoverStyle.grid) {
          paths.addAll(_coverService.sortedThumbs(album));
        } else {
          final cover = await _coverService.resolveSingleCover(album);
          if (cover != null) paths.add(cover);
        }
        if (paths.length >= _maxWarmImages) break;
      }

      final list = paths
          .where((p) => !shouldSkipCoverThumbCache(p))
          .take(_maxWarmImages)
          .toList();

      for (var i = 0; i < list.length; i += _warmBatchSize) {
        final batch = list.skip(i).take(_warmBatchSize);
        await Future.wait(batch.map(ensureThumb));
        await Future.delayed(const Duration(milliseconds: 32));
      }
    } finally {
      _warming = false;
    }
  }

  /// 清除全部封面缩略图（设置页「清理缓存」会调用）。
  Future<int> clearAll() async {
    _warming = false;
    var count = 0;
    await _removeLegacyDocumentsThumbDir();
    try {
      final dir = await _thumbDir();
      if (await dir.exists()) {
        await for (final e in dir.list()) {
          if (e is File) {
            await e.delete();
            count++;
          }
        }
      }
    } catch (_) {}
    return count;
  }

  Future<void> _purgeStaleForSource(String sourcePath, {required String keep}) async {
    final digest = sha1.convert(utf8.encode(sourcePath)).toString();
    final dir = await _thumbDir();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('${digest}_') && entity.path != keep) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }
}

class _ThumbJob {
  const _ThumbJob({
    required this.sourcePath,
    required this.maxSide,
    required this.quality,
  });

  final String sourcePath;
  final int maxSide;
  final int quality;
}

class _ThumbResult {
  const _ThumbResult({required this.bytes, required this.usePng});

  final Uint8List bytes;
  final bool usePng;
}

_ThumbResult? _generateThumbIsolate(_ThumbJob job) {
  try {
    final bytes = File(job.sourcePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final usePng = decoded.hasAlpha;
    img.Image work = decoded;

    if (work.numChannels == 1 || work.format == img.Format.uint1) {
      work = work.convert(numChannels: 3, format: img.Format.uint8);
    } else if (!usePng && work.numChannels != 3) {
      work = work.convert(numChannels: 3, format: img.Format.uint8);
    }

    final w = work.width;
    final h = work.height;
    final scale = job.maxSide / (w > h ? w : h);
    final thumb = scale >= 1
        ? work
        : img.copyResize(
            work,
            width: (w * scale).round(),
            height: (h * scale).round(),
            interpolation: img.Interpolation.linear,
          );

    final outBytes = usePng
        ? img.encodePng(thumb)
        : img.encodeJpg(thumb, quality: job.quality);
    return _ThumbResult(bytes: Uint8List.fromList(outBytes), usePng: usePng);
  } catch (_) {
    return null;
  }
}
