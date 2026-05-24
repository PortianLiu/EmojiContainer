import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../models/emoji_album.dart';
import '../services/preferences_service.dart';
import '../utils/nested_browse_utils.dart';
import '../utils/responsive_grid.dart';
import 'album_card.dart';
import 'emoji_tile.dart';

/// 嵌套模式：子文件夹卡片 + 直接图片混排网格
class NestedBrowseGrid extends StatelessWidget {
  const NestedBrowseGrid({
    super.key,
    required this.subAlbums,
    required this.imagePaths,
    required this.sortOrder,
    required this.coverStyle,
    required this.onAlbumTap,
    required this.onImageTap,
    this.onAlbumDoubleTap,
    this.onImageLongPress,
    this.selectionMode = false,
    this.selectedAlbumPaths = const {},
    this.selectedImagePaths = const {},
  });

  final List<EmojiAlbum> subAlbums;
  final List<String> imagePaths;
  final NestedSortOrder sortOrder;
  final AlbumCoverStyle coverStyle;
  final void Function(EmojiAlbum album) onAlbumTap;
  final void Function(String path, int imageIndex) onImageTap;
  final void Function(EmojiAlbum album)? onAlbumDoubleTap;
  final void Function(String path)? onImageLongPress;
  final bool selectionMode;
  final Set<String> selectedAlbumPaths;
  final Set<String> selectedImagePaths;

  @override
  Widget build(BuildContext context) {
    final entries = buildNestedBrowseEntries(
      subAlbums: subAlbums,
      imagePaths: imagePaths,
      sortOrder: sortOrder,
    );

    if (entries.isEmpty) {
      return const Center(child: Text('此目录为空'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final decodeSide = emojiCellSide(constraints.maxWidth);
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          scrollCacheExtent: ScrollCacheExtent.pixels(decodeSide * 2),
          gridDelegate: emojiGridDelegate(constraints.maxWidth),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return switch (entry) {
              NestedAlbumEntry(:final album) => AlbumCard(
                  album: album,
                  decodeSide: decodeSide,
                  coverStyle: coverStyle,
                  selectable: selectionMode,
                  selected: selectedAlbumPaths.contains(album.path),
                  onTap: () => onAlbumTap(album),
                  onDoubleTap: onAlbumDoubleTap != null
                      ? () => onAlbumDoubleTap!(album)
                      : null,
                ),
              NestedImageEntry(:final path) => EmojiTile(
                  path: path,
                  decodeSide: decodeSide,
                  selectable: selectionMode,
                  selected: selectedImagePaths.contains(path),
                  onTap: () {
                    final imageIndex = imagePaths.indexOf(path);
                    onImageTap(path, imageIndex >= 0 ? imageIndex : 0);
                  },
                  onLongPress: onImageLongPress != null
                      ? () => onImageLongPress!(path)
                      : null,
                ),
            };
          },
        );
      },
    );
  }
}
