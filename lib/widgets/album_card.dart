import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/emoji_album.dart';
import '../services/album_cover_service.dart';
import '../services/preferences_service.dart';
import 'bottom_info_overlay.dart';
import 'lazy_file_image.dart';

/// 相册卡片：九宫格或单张封面 + 名称
class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.album,
    required this.decodeSide,
    required this.onTap,
    this.onDoubleTap,
    this.selectable = false,
    this.selected = false,
    this.coverStyle = AlbumCoverStyle.grid,
  });

  final EmojiAlbum album;
  final double decodeSide;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final bool selectable;
  final bool selected;
  final AlbumCoverStyle coverStyle;

  @override
  Widget build(BuildContext context) {
    final coverService = context.read<AlbumCoverService>();

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onDoubleTap: onDoubleTap,
          child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: coverStyle == AlbumCoverStyle.grid
                      ? _GridCover(
                          thumbs: coverService.sortedThumbs(album),
                          decodeSide: decodeSide,
                        )
                      : _SingleCover(
                          album: album,
                          decodeSide: decodeSide,
                          coverService: coverService,
                        ),
                ),
                if (selectable)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white70,
                      shadows: const [Shadow(blurRadius: 4)],
                    ),
                  ),
                BottomInfoOverlay(title: album.name),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _GridCover extends StatelessWidget {
  const _GridCover({required this.thumbs, required this.decodeSide});

  final List<String> thumbs;
  final double decodeSide;

  @override
  Widget build(BuildContext context) {
    if (thumbs.isEmpty) {
      return Center(
        child: Icon(
          Icons.folder_outlined,
          size: 40,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.5),
        ),
      );
    }

    final cellSide = decodeSide / 3;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: thumbs.length,
      itemBuilder: (context, index) {
        return LazyFileImage(
          path: thumbs[index],
          decodeSide: cellSide,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class _SingleCover extends StatelessWidget {
  const _SingleCover({
    required this.album,
    required this.decodeSide,
    required this.coverService,
  });

  final EmojiAlbum album;
  final double decodeSide;
  final AlbumCoverService coverService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: coverService.resolveSingleCover(album),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null) {
          return Center(
            child: Icon(
              Icons.folder_outlined,
              size: 40,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
            ),
          );
        }
        return LazyFileImage(
          path: path,
          decodeSide: decodeSide,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
