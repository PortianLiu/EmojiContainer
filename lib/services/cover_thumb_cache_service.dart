import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/emoji_album.dart';
import 'album_cover_service.dart';
import 'preferences_service.dart';

/// 封面缩略图磁盘缓存（低分辨率 JPEG），加快首屏绘制。
class CoverThumbCacheService {
  CoverThumbCacheService({AlbumCoverService? coverService})
      : _coverService = coverService ?? AlbumCoverService();

  final AlbumCoverService _coverService;
  static const _maxSide = 240;
  static const _jpegQuality = 82;

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

  /// 返回缩略图路径；必要时在后台生成。
  Future<String?> ensureThumb(String sourcePath) async {
    final hit = await cachedThumbPath(sourcePath);
    if (hit != null) return hit;

    final src = File(sourcePath);
    if (!await src.exists()) return null;

    try {
      final bytes = await src.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final w = decoded.width;
      final h = decoded.height;
      final scale = _maxSide / (w > h ? w : h);
      final thumb = scale >= 1
          ? decoded
          : img.copyResize(
              decoded,
              width: (w * scale).round(),
              height: (h * scale).round(),
            );

      final modified = await src.lastModified();
      final out = File(
        p.join((await _thumbDir()).path, _fileName(sourcePath, modified)),
      );
      await out.writeAsBytes(img.encodeJpg(thumb, quality: _jpegQuality));
      await _purgeStaleForSource(sourcePath, keep: out.path);
      return out.path;
    } catch (_) {
      return null;
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

  /// 后台为一批表情包夹预热缩略图（不阻塞 UI）。
  Future<void> warmAlbums(
    List<EmojiAlbum> albums, {
    required AlbumCoverStyle coverStyle,
  }) async {
    for (final album in albums) {
      final paths = <String>{};
      if (coverStyle == AlbumCoverStyle.grid) {
        paths.addAll(_coverService.sortedThumbs(album));
      } else {
        final cover = await _coverService.resolveSingleCover(album);
        if (cover != null) paths.add(cover);
      }
      for (final path in paths) {
        await ensureThumb(path);
      }
    }
  }
}
