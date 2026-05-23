import 'package:flutter/material.dart';

import '../models/emoji_album.dart';
import 'bottom_info_overlay.dart';
import 'lazy_file_image.dart';

/// 相册风格卡片：封面 + 底部悬浮文件夹名
class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.album,
    required this.decodeSide,
    required this.onTap,
    this.selectable = false,
    this.selected = false,
    this.onSelectToggle,
  });

  final EmojiAlbum album;
  final double decodeSide;
  final VoidCallback onTap;
  final bool selectable;
  final bool selected;
  final VoidCallback? onSelectToggle;

  @override
  Widget build(BuildContext context) {
    final cover = album.displayCover;

    return RepaintBoundary(
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CoverImage(path: cover, decodeSide: decodeSide),
              if (selectable)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                      color: selected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              if (selectable)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white,
                    size: 26,
                  ),
                ),
              BottomInfoOverlay(
                title: album.name,
                subtitle: '${album.count} 张',
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({this.path, required this.decodeSide});

  final String? path;
  final double decodeSide;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (path == null) {
      return ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.folder_outlined,
          size: 48,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      );
    }

    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: LazyFileImage(
          path: path!,
          decodeSide: decodeSide,
          fit: BoxFit.contain,
          placeholderColor: colorScheme.surfaceContainerHighest,
          errorIcon: Icon(
            Icons.broken_image_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
