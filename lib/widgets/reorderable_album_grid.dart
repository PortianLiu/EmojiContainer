import 'package:flutter/material.dart';

import '../models/emoji_album.dart';
import '../services/preferences_service.dart';
import '../utils/responsive_grid.dart';
import 'album_card.dart';

/// 平铺首页：长按拖拽排序，双击进入多选（布局与原先 GridView 一致）
class ReorderableAlbumGrid extends StatefulWidget {
  const ReorderableAlbumGrid({
    super.key,
    required this.groups,
    required this.coverStyle,
    required this.onAlbumTap,
    required this.onAlbumDoubleTap,
    required this.onReorder,
    this.selectionMode = false,
    this.selectedPaths = const {},
  });

  final List<EmojiAlbumGroup> groups;
  final AlbumCoverStyle coverStyle;
  final void Function(EmojiAlbum album) onAlbumTap;
  final void Function(EmojiAlbum album) onAlbumDoubleTap;
  final void Function(List<EmojiAlbum> reordered) onReorder;
  final bool selectionMode;
  final Set<String> selectedPaths;

  @override
  State<ReorderableAlbumGrid> createState() => _ReorderableAlbumGridState();
}

class _ReorderableAlbumGridState extends State<ReorderableAlbumGrid> {
  late List<EmojiAlbum> _albums;

  @override
  void initState() {
    super.initState();
    _albums = _flattenGroups(widget.groups);
  }

  @override
  void didUpdateWidget(ReorderableAlbumGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groups != widget.groups) {
      _albums = _flattenGroups(widget.groups);
    }
  }

  List<EmojiAlbum> _flattenGroups(List<EmojiAlbumGroup> groups) {
    return groups.expand((g) => g.albums).toList();
  }

  int _globalIndex(String path) =>
      _albums.indexWhere((album) => album.path == path);

  void _reorder(int from, int to) {
    if (from == to ||
        from < 0 ||
        to < 0 ||
        from >= _albums.length ||
        to >= _albums.length) {
      return;
    }
    setState(() {
      final item = _albums.removeAt(from);
      _albums.insert(to, item);
    });
    widget.onReorder(List<EmojiAlbum>.from(_albums));
  }

  Widget _buildDraggableTile({
    required int index,
    required double decodeSide,
  }) {
    if (index < 0) {
      return const SizedBox.shrink();
    }

    final album = _albums[index];
    final canDrag = !widget.selectionMode;

    final card = AlbumCard(
      album: album,
      decodeSide: decodeSide,
      coverStyle: widget.coverStyle,
      selectable: widget.selectionMode,
      selected: widget.selectedPaths.contains(album.path),
      onTap: () => widget.onAlbumTap(album),
      onDoubleTap: () => widget.onAlbumDoubleTap(album),
    );

    if (!canDrag) return card;

    return LongPressDraggable<int>(
      data: index,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: decodeSide,
          height: decodeSide,
          child: AlbumCard(
            album: album,
            decodeSide: decodeSide,
            coverStyle: widget.coverStyle,
            onTap: () {},
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (d) => d.data != index,
        onAcceptWithDetails: (d) => _reorder(d.data, index),
        builder: (context, candidateData, rejectedData) {
          final highlighted = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: highlighted
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  )
                : null,
            child: card,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNamedGroups = widget.groups.any((g) => g.name != null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final decodeSide = albumCellSide(constraints.maxWidth);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: widget.groups.length,
          itemBuilder: (context, groupIndex) {
            final group = widget.groups[groupIndex];
            if (group.albums.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (group.name != null) ...[
                  if (groupIndex > 0) const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.label_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          group.name!,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ] else if (hasNamedGroups) ...[
                  if (groupIndex > 0) const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      '未分组',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  gridDelegate: albumGridDelegate(constraints.maxWidth),
                  itemCount: group.albums.length,
                  itemBuilder: (context, index) {
                    final album = group.albums[index];
                    return _buildDraggableTile(
                      index: _globalIndex(album.path),
                      decodeSide: decodeSide,
                    );
                  },
                ),
                if (groupIndex < widget.groups.length - 1) const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }
}
