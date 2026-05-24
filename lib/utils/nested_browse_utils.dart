import 'dart:io';

import '../models/emoji_album.dart';
import '../services/preferences_service.dart';
import '../utils/file_time_utils.dart';

/// 嵌套模式下单层目录的展示项（子文件夹卡片 + 直接图片）
sealed class NestedBrowseEntry {}

class NestedAlbumEntry extends NestedBrowseEntry {
  NestedAlbumEntry(this.album);
  final EmojiAlbum album;
}

class NestedImageEntry extends NestedBrowseEntry {
  NestedImageEntry(this.path);
  final String path;
}

List<NestedBrowseEntry> buildNestedBrowseEntries({
  required List<EmojiAlbum> subAlbums,
  required List<String> imagePaths,
  required NestedSortOrder sortOrder,
}) {
  switch (sortOrder) {
    case NestedSortOrder.foldersFirst:
      return [
        ...subAlbums.map(NestedAlbumEntry.new),
        ...imagePaths.map(NestedImageEntry.new),
      ];
    case NestedSortOrder.imagesFirst:
      return [
        ...imagePaths.map(NestedImageEntry.new),
        ...subAlbums.map(NestedAlbumEntry.new),
      ];
    case NestedSortOrder.modifiedTime:
      final scored = <(int key, NestedBrowseEntry entry)>[];
      for (final album in subAlbums) {
        scored.add((
          _dirModifiedMillis(album.path),
          NestedAlbumEntry(album),
        ));
      }
      for (final path in imagePaths) {
        scored.add((
          fileModifiedMillisSync(path),
          NestedImageEntry(path),
        ));
      }
      scored.sort((a, b) => b.$1.compareTo(a.$1));
      return scored.map((e) => e.$2).toList();
  }
}

int _dirModifiedMillis(String path) {
  try {
    return FileStat.statSync(path).modified.millisecondsSinceEpoch;
  } catch (_) {
    return 0;
  }
}
