import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/emoji_album.dart';

/// 相册列表磁盘缓存，加快启动
class AlbumCacheService {
  static const _fileName = 'albums_cache.json';

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<List<EmojiAlbum>?> load(String rootPath) async {
    final file = await _cacheFile();
    if (!await file.exists()) return null;

    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['rootPath'] as String != rootPath) return null;

      final list = json['albums'] as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return EmojiAlbum(
          name: m['name'] as String,
          path: m['path'] as String,
          emojiPaths: List<String>.from(m['emojiPaths'] as List),
          coverPath: m['coverPath'] as String?,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String rootPath, List<EmojiAlbum> albums) async {
    final file = await _cacheFile();
    final data = {
      'rootPath': rootPath,
      'cachedAt': DateTime.now().toIso8601String(),
      'albums': albums
          .map(
            (a) => {
              'name': a.name,
              'path': a.path,
              'emojiPaths': a.emojiPaths,
              'coverPath': a.coverPath,
            },
          )
          .toList(),
    };
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> clear() async {
    final file = await _cacheFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
