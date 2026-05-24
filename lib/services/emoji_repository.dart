import 'dart:io';

import '../models/emoji_album.dart';
import '../services/preferences_service.dart';
import '../utils/file_time_utils.dart';
import 'album_group_service.dart';
import 'album_cover_service.dart';
import 'emoji_constants.dart';

class EmojiRepository {
  static const skipDirNames = {'camera', '.emoji_container_exports'};

  Future<List<EmojiAlbumGroup>> loadGroupedAlbums(
    String rootPath,
    BrowseMode mode, {
    AlbumGroupService? groupService,
    AlbumOrderService? orderService,
  }) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      throw EmojiRepositoryException('目录不存在：$rootPath');
    }

    if (mode == BrowseMode.nested) {
      return [];
    }

    final albums = await _collectFlatAlbums(root);
    final order = orderService ?? AlbumOrderService();
    final sorted = order.applyOrder(albums, await order.loadOrder(rootPath));

    final service = groupService ?? AlbumGroupService();
    return service.buildDisplayGroups(rootPath, sorted);
  }

  /// 嵌套模式：浏览某一层的直接子文件夹 + 直接子图片
  Future<EmojiAlbumContents> loadContents(
    String dirPath,
    BrowseMode mode, {
    NestedSortOrder sortOrder = NestedSortOrder.foldersFirst,
  }) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw EmojiRepositoryException('目录不存在：$dirPath');
    }

    final directImages = await _collectImages(dir, recursive: false);
    sortPathsByTimeDescSync(directImages);

    if (mode == BrowseMode.flat) {
      return EmojiAlbumContents(
        name: _folderName(dirPath),
        path: dirPath,
        emojiPaths: directImages,
        imageCount: directImages.length,
      );
    }

    final subAlbums = await _loadNestedSubAlbums(dir);
    return EmojiAlbumContents(
      name: _folderName(dirPath),
      path: dirPath,
      emojiPaths: directImages,
      subAlbums: subAlbums,
      imageCount: directImages.length + _sumDirectCounts(subAlbums),
    );
  }

  /// 嵌套模式根目录浏览（首页）
  Future<EmojiAlbumContents> loadNestedRoot(String rootPath) async {
    return loadContents(rootPath, BrowseMode.nested);
  }

  Future<List<EmojiAlbum>> loadAlbums(String rootPath, [BrowseMode? mode]) async {
    final groups = await loadGroupedAlbums(rootPath, mode ?? BrowseMode.flat);
    return groups.expand((g) => g.albums).toList();
  }

  /// 平铺扫描 + 手动排序，不含分组
  Future<List<EmojiAlbum>> loadFlatAlbumsOrdered(
    String rootPath, {
    AlbumOrderService? orderService,
  }) async {
    final root = Directory(rootPath);
    if (!await root.exists()) {
      throw EmojiRepositoryException('目录不存在：$rootPath');
    }
    final albums = await _collectFlatAlbums(root);
    final order = orderService ?? AlbumOrderService();
    return order.applyOrder(albums, await order.loadOrder(rootPath));
  }

  /// 递归收集所有含直接图片的文件夹，平铺为同级表情包夹
  Future<List<EmojiAlbum>> _collectFlatAlbums(Directory root) async {
    final albums = <EmojiAlbum>[];
    await _walkFlatAlbums(root, albums);
    return albums;
  }

  Future<void> _walkFlatAlbums(Directory dir, List<EmojiAlbum> out) async {
    final directImages = await _collectImages(dir, recursive: false);
    if (directImages.isNotEmpty) {
      sortPathsByTimeDescSync(directImages);
      out.add(
        EmojiAlbum(
          name: _folderName(dir.path),
          path: dir.path,
          emojiPaths: directImages,
          coverPath: _pickNewestCover(directImages),
          imageCount: directImages.length,
        ),
      );
    }

    for (final child in await _listChildDirs(dir)) {
      await _walkFlatAlbums(child, out);
    }
  }

  Future<List<EmojiAlbum>> _loadNestedSubAlbums(Directory parent) async {
    final albums = <EmojiAlbum>[];
    for (final dir in await _listChildDirs(parent)) {
      final directImages = await _collectImages(dir, recursive: false);
      final childDirs = await _listChildDirs(dir);
      if (directImages.isEmpty && childDirs.isEmpty) continue;

      sortPathsByTimeDescSync(directImages);
      albums.add(
        EmojiAlbum(
          name: _folderName(dir.path),
          path: dir.path,
          emojiPaths: directImages,
          coverPath: _pickNewestCover(directImages),
          imageCount: directImages.length,
        ),
      );
    }

    albums.sort(
      (a, b) =>
          _directoryModifiedMillis(b.path).compareTo(_directoryModifiedMillis(a.path)),
    );
    return albums;
  }

  int _sumDirectCounts(List<EmojiAlbum> albums) {
    return albums.fold(0, (sum, a) => sum + a.emojiPaths.length);
  }

  Future<List<Directory>> _listChildDirs(Directory parent) async {
    final result = <Directory>[];
    await for (final entity in parent.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = _folderName(entity.path);
      if (_shouldSkipDir(name)) continue;
      result.add(entity);
    }
    result.sort(
      (a, b) => _folderName(a.path).compareTo(_folderName(b.path)),
    );
    return result;
  }

  bool _shouldSkipDir(String name) =>
      name.startsWith('.') || skipDirNames.contains(name);

  String? _pickNewestCover(List<String> paths) {
    if (paths.isEmpty) return null;
    final sorted = List<String>.from(paths);
    sortPathsByTimeDescSync(sorted);
    return sorted.first;
  }

  int _directoryModifiedMillis(String path) {
    try {
      return FileStat.statSync(path).modified.millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  Future<List<String>> _collectImages(
    Directory dir, {
    required bool recursive,
  }) async {
    final result = <String>[];
    await for (final entity in dir.list(
      recursive: recursive,
      followLinks: false,
    )) {
      if (entity is File && isImageFile(entity.path)) {
        result.add(entity.path);
      }
    }
    return result;
  }

  String _folderName(String path) {
    final sep = Platform.pathSeparator;
    if (path.endsWith(sep)) {
      path = path.substring(0, path.length - 1);
    }
    final i = path.lastIndexOf(sep);
    return i < 0 ? path : path.substring(i + 1);
  }
}

class EmojiRepositoryException implements Exception {
  EmojiRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
