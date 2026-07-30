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

  /// 首页九宫格：优先用扫描/缓存写好的 [EmojiAlbum.coverThumbs]，避免每次 build 全量排序。
  List<String> sortedThumbs(EmojiAlbum album, {int max = 9}) {
    if (album.coverThumbs.isNotEmpty) {
      return album.coverThumbs.take(max).toList();
    }
    if (album.emojiPaths.isEmpty) return const [];
    final paths = List<String>.from(album.emojiPaths);
    sortPathsByTimeDescSync(paths);
    return paths.take(max).toList();
  }

  String? defaultCoverPath(EmojiAlbum album) {
    if (album.coverPath != null && album.coverPath!.isNotEmpty) {
      return album.coverPath;
    }
    final sorted = sortedThumbs(album, max: 1);
    if (sorted.isNotEmpty) return sorted.first;
    return null;
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

  /// 后台扫描完成后：磁盘缓存写新封面；本次 UI 仍沿用旧封面（SWR）。
  /// 新出现的相册使用扫描得到的封面。
  static List<EmojiAlbumGroup> preserveDisplayCovers({
    required List<EmojiAlbumGroup> previous,
    required List<EmojiAlbumGroup> fresh,
  }) {
    final oldByPath = <String, EmojiAlbum>{
      for (final album in previous.expand((g) => g.albums)) album.path: album,
    };

    return [
      for (final group in fresh)
        EmojiAlbumGroup(
          id: group.id,
          name: group.name,
          albums: [
            for (final album in group.albums)
              _keepPreviousCoverIfAny(oldByPath[album.path], album),
          ],
        ),
    ];
  }

  static EmojiAlbum _keepPreviousCoverIfAny(EmojiAlbum? previous, EmojiAlbum fresh) {
    if (previous == null) return fresh;
    final oldThumbs = previous.coverThumbs;
    if (oldThumbs.isEmpty && previous.coverPath == null) return fresh;
    return fresh.copyWith(
      coverPath: previous.coverPath ?? fresh.coverPath,
      coverThumbs: oldThumbs.isNotEmpty ? oldThumbs : fresh.coverThumbs,
    );
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
      sortAlbumsByActivityDesc(sorted);
      return sorted;
    }

    final byPath = {for (final a in albums) a.path: a};
    final result = <EmojiAlbum>[];
    for (final path in savedOrder) {
      final album = byPath.remove(path);
      if (album != null) result.add(album);
    }
    final rest = byPath.values.toList();
    sortAlbumsByActivityDesc(rest);
    result.addAll(rest);
    return result;
  }
}
