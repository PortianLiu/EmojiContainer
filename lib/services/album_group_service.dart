import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/emoji_album.dart';
import '../models/manual_album_group.dart';

class AlbumGroupService {
  static final _random = Random();

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(0x7FFFFFFF)}';

  String _keyForRoot(String rootPath) =>
      'manual_album_groups_${Uri.encodeComponent(rootPath)}';

  Future<List<ManualAlbumGroup>> loadGroups(String rootPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForRoot(rootPath));
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ManualAlbumGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveGroups(String rootPath, List<ManualAlbumGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final data = groups.map((g) => g.toJson()).toList();
    await prefs.setString(_keyForRoot(rootPath), jsonEncode(data));
  }

  Future<ManualAlbumGroup> createGroup(String rootPath, String name) async {
    final groups = await loadGroups(rootPath);
    final group = ManualAlbumGroup(
      id: _newId(),
      name: name.trim(),
      albumPaths: [],
    );
    groups.add(group);
    await saveGroups(rootPath, groups);
    return group;
  }

  Future<void> renameGroup(String rootPath, String groupId, String name) async {
    final groups = await loadGroups(rootPath);
    final idx = groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    groups[idx] = groups[idx].copyWith(name: name.trim());
    await saveGroups(rootPath, groups);
  }

  Future<void> deleteGroup(String rootPath, String groupId) async {
    final groups = await loadGroups(rootPath);
    groups.removeWhere((g) => g.id == groupId);
    await saveGroups(rootPath, groups);
  }

  Future<void> assignAlbumsToGroup(
    String rootPath,
    String groupId,
    List<String> albumPaths,
  ) async {
    if (albumPaths.isEmpty) return;
    var groups = await loadGroups(rootPath);
    final pathSet = albumPaths.toSet();

    groups = groups.map((g) {
      final filtered =
          g.albumPaths.where((p) => !pathSet.contains(p)).toList();
      return g.copyWith(albumPaths: filtered);
    }).toList();

    final idx = groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;

    final merged = {...groups[idx].albumPaths, ...albumPaths}.toList();
    groups[idx] = groups[idx].copyWith(albumPaths: merged);
    await saveGroups(rootPath, groups);
  }

  Future<void> removeAlbumFromAllGroups(String rootPath, String albumPath) async {
    final groups = await loadGroups(rootPath);
    final updated = groups
        .map(
          (g) => g.copyWith(
            albumPaths: g.albumPaths.where((p) => p != albumPath).toList(),
          ),
        )
        .toList();
    await saveGroups(rootPath, updated);
  }

  Future<void> removeAlbumsFromAllGroups(
    String rootPath,
    List<String> albumPaths,
  ) async {
    final pathSet = albumPaths.toSet();
    final groups = await loadGroups(rootPath);
    final updated = groups
        .map(
          (g) => g.copyWith(
            albumPaths: g.albumPaths.where((p) => !pathSet.contains(p)).toList(),
          ),
        )
        .toList();
    await saveGroups(rootPath, updated);
  }

  Future<List<EmojiAlbumGroup>> buildDisplayGroups(
    String rootPath,
    List<EmojiAlbum> allAlbums,
  ) async {
    var manualGroups = await loadGroups(rootPath);
    final albumByPath = {for (final a in allAlbums) a.path: a};
    final assigned = <String>{};
    final result = <EmojiAlbumGroup>[];

    manualGroups = manualGroups
        .map(
          (g) => g.copyWith(
            albumPaths:
                g.albumPaths.where((p) => albumByPath.containsKey(p)).toList(),
          ),
        )
        .toList();
    await saveGroups(rootPath, manualGroups);

    for (final g in manualGroups) {
      final albums = <EmojiAlbum>[];
      for (final path in g.albumPaths) {
        final album = albumByPath[path];
        if (album != null) {
          albums.add(album);
          assigned.add(path);
        }
      }
      if (albums.isNotEmpty) {
        result.add(
          EmojiAlbumGroup(id: g.id, name: g.name, albums: albums),
        );
      }
    }

    final ungrouped =
        allAlbums.where((a) => !assigned.contains(a.path)).toList();
    if (ungrouped.isNotEmpty) {
      result.insert(0, EmojiAlbumGroup(name: null, albums: ungrouped));
    }

    return result;
  }
}
