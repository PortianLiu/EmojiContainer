import 'dart:io';

import '../services/preferences_service.dart';
import 'emoji_repository.dart';

class EmojiDeleteService {
  EmojiDeleteService({EmojiRepository? repository})
      : _repository = repository ?? EmojiRepository();

  final EmojiRepository _repository;

  Future<int> deleteFiles(List<String> paths) async {
    var count = 0;
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  Future<bool> deleteAlbumDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return false;
    await dir.delete(recursive: true);
    return true;
  }

  Future<int> countImagesInAlbum(String dirPath, BrowseMode mode) async {
    final contents = await _repository.loadContents(dirPath, mode);
    return contents.count;
  }

  Future<bool> albumHasImages(String dirPath, BrowseMode mode) async {
    return (await countImagesInAlbum(dirPath, mode)) > 0;
  }
}
