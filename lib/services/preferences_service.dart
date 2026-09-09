import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_share_channel.dart';

enum ImportMode { cut, copy }

extension ImportModeLabels on ImportMode {
  String get actionVerb => this == ImportMode.cut ? '移动' : '复制';

  String get settingsTitle =>
      this == ImportMode.cut ? '移动（默认）' : '复制';
}

enum BrowseMode { flat, nested }

extension BrowseModeLabels on BrowseMode {
  String get settingsTitle =>
      this == BrowseMode.flat ? '平铺（默认）' : '嵌套';

  String get settingsSubtitle => this == BrowseMode.flat
      ? '所有文件夹平铺为同级表情包夹，仅含各自直接子图片'
      : '按目录层级浏览：先子文件夹再直接子图片（可调整顺序）';
}

/// 嵌套模式下同级内容的排序
enum NestedSortOrder { foldersFirst, imagesFirst, modifiedTime }

extension NestedSortOrderLabels on NestedSortOrder {
  String get settingsTitle => switch (this) {
        NestedSortOrder.foldersFirst => '子文件夹优先',
        NestedSortOrder.imagesFirst => '直接图片优先',
        NestedSortOrder.modifiedTime => '按修改时间',
      };
}

/// 表情包夹卡片封面样式
enum AlbumCoverStyle { grid, single }

extension AlbumCoverStyleLabels on AlbumCoverStyle {
  String get settingsTitle => switch (this) {
        AlbumCoverStyle.grid => '九宫格（默认）',
        AlbumCoverStyle.single => '单张封面',
      };
}

class PreferencesService {
  static const _keyRootDirectory = 'root_directory';
  static const _keyAlbumCreateRoot = 'album_create_root';
  static const _keyImportMode = 'import_mode';
  static const _keyBrowseMode = 'browse_mode';
  static const _keyAutoNomedia = 'auto_nomedia';
  static const _keyAlbumCoverStyle = 'album_cover_style';
  static const _keyNestedSortOrder = 'nested_sort_order';
  static const _keyCustomCoverPrefix = 'custom_cover_';
  static const _keyAdvancedSettings = 'advanced_settings';
  static const _keyCustomShareChannels = 'custom_share_channels';

  Future<bool> getAdvancedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAdvancedSettings) ?? false;
  }

  Future<void> setAdvancedSettings(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAdvancedSettings, enabled);
  }

  Future<List<CustomShareChannel>> getCustomShareChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCustomShareChannels);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => CustomShareChannel.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .where((c) => c.packageName.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setCustomShareChannels(List<CustomShareChannel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(channels.map((c) => c.toJson()).toList());
    await prefs.setString(_keyCustomShareChannels, encoded);
  }

  Future<String?> getRootDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRootDirectory);
  }

  Future<void> setRootDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRootDirectory, path);
  }

  Future<void> clearRootDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRootDirectory);
  }

  Future<String?> getAlbumCreateRoot() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAlbumCreateRoot);
  }

  Future<void> setAlbumCreateRoot(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_keyAlbumCreateRoot);
    } else {
      await prefs.setString(_keyAlbumCreateRoot, path);
    }
  }

  Future<ImportMode> getImportMode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyImportMode);
    return v == 'copy' ? ImportMode.copy : ImportMode.cut;
  }

  Future<void> setImportMode(ImportMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyImportMode,
      mode == ImportMode.copy ? 'copy' : 'cut',
    );
  }

  Future<BrowseMode> getBrowseMode() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyBrowseMode);
    return v == 'nested' ? BrowseMode.nested : BrowseMode.flat;
  }

  Future<void> setBrowseMode(BrowseMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyBrowseMode,
      mode == BrowseMode.nested ? 'nested' : 'flat',
    );
  }

  Future<bool> getAutoNomedia() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoNomedia) ?? false;
  }

  Future<void> setAutoNomedia(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoNomedia, enabled);
  }

  Future<AlbumCoverStyle> getAlbumCoverStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAlbumCoverStyle) == 'single'
        ? AlbumCoverStyle.single
        : AlbumCoverStyle.grid;
  }

  Future<void> setAlbumCoverStyle(AlbumCoverStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyAlbumCoverStyle,
      style == AlbumCoverStyle.single ? 'single' : 'grid',
    );
  }

  Future<NestedSortOrder> getNestedSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_keyNestedSortOrder)) {
      'imagesFirst' => NestedSortOrder.imagesFirst,
      'modifiedTime' => NestedSortOrder.modifiedTime,
      _ => NestedSortOrder.foldersFirst,
    };
  }

  Future<void> setNestedSortOrder(NestedSortOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyNestedSortOrder,
      switch (order) {
        NestedSortOrder.imagesFirst => 'imagesFirst',
        NestedSortOrder.modifiedTime => 'modifiedTime',
        NestedSortOrder.foldersFirst => 'foldersFirst',
      },
    );
  }

  String _coverKey(String albumPath) =>
      '$_keyCustomCoverPrefix${Uri.encodeComponent(albumPath)}';

  Future<String?> getCustomCoverPath(String albumPath) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_coverKey(albumPath));
  }

  Future<void> setCustomCoverPath(String albumPath, String? imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _coverKey(albumPath);
    if (imagePath == null || imagePath.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, imagePath);
    }
  }
}
