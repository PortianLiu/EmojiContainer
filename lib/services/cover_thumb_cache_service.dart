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

/// 封面缩略图磁盘缓存（低分辨率 JPEG），加快首屏绘制。
/// GIF/WebP 动图不缓存，直接读原文件首帧。
class CoverThumbCacheService {
  CoverThumbCacheService({AlbumCoverService? coverService})
      : _coverService = coverService ?? AlbumCoverService();

  final AlbumCoverService _coverService;
  static const _maxSide = 240;
  static const _jpegQuality = 85;
  static const _maxWarmImages = 48;
  static const _warmBatchSize = 2;

  bool _warming = false;

  Future<Directory> _thumbDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'cover_thumbs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _fileName(String sourcePath, DateTime modified) {
    final digest = sha1.convert(utf8.encode(sourcePath)).toString();
    return '${digest}_${modified.millisecondsSinceEpoch}.jpg';
  }

  /// 若缓存仍与源文件修改时间一致则返回缩略图路径。
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
    final file = File(
      p.join((await _thumbDir()).path, _fileName(sourcePath, modified)),
    );
    if (await file.exists()) return file.path;
    return null;
  }

  /// 在 isolate 中生成缩略图，避免阻塞 UI / OOM。
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

    final outPath = p.join(
      (await _thumbDir()).path,
      _fileName(sourcePath, modified),
    );

    try {
      final ok = await compute(
        _generateThumbIsolate,
        _ThumbJob(
          sourcePath: sourcePath,
          outPath: outPath,
          maxSide: _maxSide,
          quality: _jpegQuality,
        ),
      );
      if (!ok) return null;
      await _purgeStaleForSource(sourcePath, keep: outPath);
      return outPath;
    } catch (_) {
      return null;
    }
  }

  /// 后台预热（低优先级、限数量），勿在首屏同步调用。
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
    required this.outPath,
    required this.maxSide,
    required this.quality,
  });

  final String sourcePath;
  final String outPath;
  final int maxSide;
  final int quality;
}

/// 顶层函数供 [compute] 调用。
bool _generateThumbIsolate(_ThumbJob job) {
  try {
    final bytes = File(job.sourcePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return false;

    var image = _prepareForJpeg(decoded);

    final w = image.width;
    final h = image.height;
    final scale = job.maxSide / (w > h ? w : h);
    final thumb = scale >= 1
        ? image
        : img.copyResize(
            image,
            width: (w * scale).round(),
            height: (h * scale).round(),
            interpolation: img.Interpolation.linear,
          );

    File(job.outPath).writeAsBytesSync(
      img.encodeJpg(thumb, quality: job.quality),
    );
    return true;
  } catch (_) {
    return false;
  }
}

img.Image _prepareForJpeg(img.Image decoded) {
  img.Image work = decoded;

  if (work.numChannels == 1 || work.format == img.Format.uint1) {
    work = work.convert(numChannels: 3, format: img.Format.uint8);
  }

  if (work.hasAlpha) {
    final flat = img.Image(
      width: work.width,
      height: work.height,
      numChannels: 3,
      format: img.Format.uint8,
    );
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, work);
    work = flat;
  } else if (work.numChannels != 3) {
    work = work.convert(numChannels: 3, format: img.Format.uint8);
  }

  return work;
}
