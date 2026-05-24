import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/emoji_album.dart';
import '../utils/file_time_utils.dart';
import 'preferences_service.dart';

/// 解析封面：自选封面 / 九宫格最新 9 张 / 默认最新一张
class AlbumCoverService {
  AlbumCoverService({PreferencesService? preferences})
      : _preferences = preferences ?? PreferencesService();

  final PreferencesService _preferences;

  List<String> sortedThumbs(EmojiAlbum album, {int max = 9}) {
    final paths = List<String>.from(album.emojiPaths);
    sortPathsByTimeDescSync(paths);
    return paths.take(max).toList();
  }

  String? defaultCoverPath(EmojiAlbum album) {
    final sorted = sortedThumbs(album, max: 1);
    return sorted.isEmpty ? album.coverPath : sorted.first;
  }

  Future<String?> resolveSingleCover(EmojiAlbum album) async {
    final custom = await _preferences.getCustomCoverPath(album.path);
    if (custom != null && await File(custom).exists()) {
      return custom;
    }
    return defaultCoverPath(album);
  }

  Future<void> setCustomCover(String albumPath, String imagePath) async {
    await _preferences.setCustomCoverPath(albumPath, imagePath);
  }

  Future<void> clearCustomCover(String albumPath) async {
    await _preferences.setCustomCoverPath(albumPath, null);
  }
}

/// 平铺模式下列表排序（手动顺序 + 未收录的按修改时间）
class AlbumOrderService {
  String _keyForRoot(String rootPath) =>
      'album_order_${Uri.encodeComponent(rootPath)}';

  Future<List<String>> loadOrder(String rootPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForRoot(rootPath));
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveOrder(String rootPath, List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    if (paths.isEmpty) {
      await prefs.remove(_keyForRoot(rootPath));
    } else {
      await prefs.setString(_keyForRoot(rootPath), jsonEncode(paths));
    }
  }

  /// 清除手动排序，恢复为按文件夹修改时间倒序
  Future<void> clearOrder(String rootPath) async {
    await saveOrder(rootPath, []);
  }

  List<EmojiAlbum> applyOrder(List<EmojiAlbum> albums, List<String> savedOrder) {
    if (savedOrder.isEmpty) {
      final sorted = List<EmojiAlbum>.from(albums);
      sorted.sort(
        (a, b) => _dirModified(b.path).compareTo(_dirModified(a.path)),
      );
      return sorted;
    }

    final byPath = {for (final a in albums) a.path: a};
    final result = <EmojiAlbum>[];
    for (final path in savedOrder) {
      final album = byPath.remove(path);
      if (album != null) result.add(album);
    }
    final rest = byPath.values.toList()
      ..sort((a, b) => _dirModified(b.path).compareTo(_dirModified(a.path)));
    result.addAll(rest);
    return result;
  }

  int _dirModified(String path) {
    try {
      return FileStat.statSync(path).modified.millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }
}
