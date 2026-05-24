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

  Future<List<EmojiAlbumGroup>?> loadGroups(String rootPath) async {
    final file = await _cacheFile();
    if (!await file.exists()) return null;

    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['rootPath'] as String != rootPath) return null;

      final list = json['groups'] as List<dynamic>? ??
          [
            {
              'name': null,
              'albums': json['albums'] as List<dynamic>? ?? [],
            },
          ];

      return list.map((e) {
        final m = e as Map<String, dynamic>;
        final albums = (m['albums'] as List<dynamic>).map(_albumFromJson).toList();
        return EmojiAlbumGroup(
          name: m['name'] as String?,
          albums: albums,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  EmojiAlbum _albumFromJson(dynamic e) {
    final m = e as Map<String, dynamic>;
    return EmojiAlbum(
      name: m['name'] as String,
      path: m['path'] as String,
      emojiPaths: List<String>.from(m['emojiPaths'] as List),
      coverPath: m['coverPath'] as String?,
      imageCount: m['imageCount'] as int?,
    );
  }

  Future<List<EmojiAlbum>?> load(String rootPath) async {
    final groups = await loadGroups(rootPath);
    if (groups == null) return null;
    return groups.expand((g) => g.albums).toList();
  }

  Future<void> saveGroups(String rootPath, List<EmojiAlbumGroup> groups) async {
    final file = await _cacheFile();
    final data = {
      'rootPath': rootPath,
      'cachedAt': DateTime.now().toIso8601String(),
      'groups': groups
          .map(
            (g) => {
              'name': g.name,
              'albums': g.albums
                  .map(
                    (a) => {
                      'name': a.name,
                      'path': a.path,
                      'emojiPaths': a.emojiPaths,
                      'coverPath': a.coverPath,
                      'imageCount': a.imageCount,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> save(String rootPath, List<EmojiAlbum> albums) async {
    await saveGroups(
      rootPath,
      [EmojiAlbumGroup(name: null, albums: albums)],
    );
  }

  Future<void> clear() async {
    final file = await _cacheFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
