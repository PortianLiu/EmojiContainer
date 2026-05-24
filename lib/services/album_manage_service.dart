import 'dart:io';

import 'package:path/path.dart' as p;

import 'preferences_service.dart';

class AlbumManageService {
  AlbumManageService({PreferencesService? preferences})
      : _preferences = preferences ?? PreferencesService();

  final PreferencesService _preferences;

  Future<String> resolveCreateParent(String rootPath) async {
    final custom = await _preferences.getAlbumCreateRoot();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return rootPath;
  }

  Future<String> createAlbum({
    required String rootPath,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw AlbumManageException('名称不能为空');
    }
    if (trimmed.contains(RegExp(r'[\\/:*?"<>|]'))) {
      throw AlbumManageException('名称不能包含 \\ / : * ? " < > |');
    }

    final parent = await resolveCreateParent(rootPath);
    final dir = Directory(p.join(parent, trimmed));
    if (await dir.exists()) {
      throw AlbumManageException('该表情包夹已存在');
    }
    await dir.create(recursive: true);
    return dir.path;
  }
}

class AlbumManageException implements Exception {
  AlbumManageException(this.message);
  final String message;

  @override
  String toString() => message;
}
