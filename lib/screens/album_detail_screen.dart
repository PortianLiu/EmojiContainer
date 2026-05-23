import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/root_directory/root_directory_cubit.dart';
import '../models/emoji_album.dart';
import '../models/emoji_export_item.dart';
import '../services/camera_export_service.dart';
import '../services/gallery_image_exporter.dart';
import '../utils/file_name_utils.dart';
import '../utils/file_time_utils.dart';
import '../utils/platform_utils.dart';
import '../utils/responsive_grid.dart';
import '../widgets/bottom_info_overlay.dart';
import '../widgets/desktop_copy_button.dart';
import '../widgets/draggable_emoji_wrapper.dart';
import '../widgets/emoji_tile.dart';
import '../widgets/swipe_up_to_share.dart';
import 'camera_export_history_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({super.key, required this.album});

  final EmojiAlbum album;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  late final List<String> _sortedPaths;
  bool _selectionMode = false;
  final Set<String> _selectedPaths = {};
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _sortedPaths = List<String>.from(widget.album.emojiPaths);
    // 先展示网格，排序放到首帧之后，避免打开大包时卡住
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sortPathsByTimeDescSync(_sortedPaths);
      setState(() {});
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedPaths.clear();
    });
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  Future<void> _exportToCamera() async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null || _selectedPaths.isEmpty) return;

    if (useGalleryExport && !await GalleryImageExporter.ensureAccess()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未获得相册写入权限，无法保存到相册')),
      );
      return;
    }

    setState(() => _exporting = true);

    try {
      final items = _selectedPaths
          .map(
            (path) => EmojiExportItem(
              sourcePath: path,
              albumName: widget.album.name,
            ),
          )
          .toList();

      final result = await context.read<CameraExportService>().exportEmojis(
            fallbackRoot: root,
            items: items,
          );

      if (!mounted) return;
      _exitSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已复制 ${result.copiedCount} 张\n${result.locationDescription}',
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: '查看记录',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CameraExportHistoryScreen(),
                ),
              );
            },
          ),
        ),
      );
    } on CameraExportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on GalleryExportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('复制失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showPreview(String path, int initialIndex) {
    if (_selectionMode) {
      _toggleSelection(path);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EmojiPreviewPage(
          paths: _sortedPaths,
          initialIndex: initialIndex,
          title: widget.album.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = supportsSystemShare;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '已选 ${_selectedPaths.length} 张'
              : widget.album.name,
        ),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (!_selectionMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${widget.album.count} 张',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          if (mobile && !_selectionMode && _sortedPaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.checklist_outlined),
              tooltip: '选择表情复制到 Camera',
              onPressed: () => setState(() => _selectionMode = true),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (supportsOutboundDrag && !_selectionMode) const _DesktopSendHint(),
          if (supportsSystemShare && !_selectionMode) const _MobileLongPressHint(),
          if (_selectionMode)
            Material(
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withValues(alpha: 0.6),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  '点选要复制的表情',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                      ),
                ),
              ),
            ),
          Expanded(
            child: _sortedPaths.isEmpty
                ? const _EmptyAlbum()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final decodeSide = emojiCellSide(constraints.maxWidth);
                      return GridView.builder(
                        padding: const EdgeInsets.all(8),
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                        scrollCacheExtent:
                            ScrollCacheExtent.pixels(decodeSide * 2),
                        gridDelegate:
                            emojiGridDelegate(constraints.maxWidth),
                        itemCount: _sortedPaths.length,
                        itemBuilder: (context, index) {
                          final path = _sortedPaths[index];
                          return EmojiTile(
                            path: path,
                            decodeSide: decodeSide,
                            selectable: _selectionMode,
                            selected: _selectedPaths.contains(path),
                            onTap: () => _showPreview(path, index),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selectionMode && mobile
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  onPressed: _exporting || _selectedPaths.isEmpty
                      ? null
                      : _exportToCamera,
                  icon: _exporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.copy_all_outlined),
                  label: Text(
                    _exporting
                        ? '复制中…'
                        : '复制到 Camera (${_selectedPaths.length})',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _DesktopSendHint extends StatelessWidget {
  const _DesktopSendHint();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '按住表情图片拖动到聊天窗口，或点击标题右侧复制图标后粘贴',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileLongPressHint extends StatelessWidget {
  const _MobileLongPressHint();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '长按分享；点右上角列表可多选复制到 Camera',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAlbum extends StatelessWidget {
  const _EmptyAlbum();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '该表情包集为空',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '请在此文件夹中添加图片文件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmojiPreviewPage extends StatefulWidget {
  const _EmojiPreviewPage({
    required this.paths,
    required this.initialIndex,
    required this.title,
  });

  final List<String> paths;
  final int initialIndex;
  final String title;

  @override
  State<_EmojiPreviewPage> createState() => _EmojiPreviewPageState();
}

class _EmojiPreviewPageState extends State<_EmojiPreviewPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${widget.title} (${_currentIndex + 1}/${widget.paths.length})',
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final path = widget.paths[index];
          final name = fileDisplayName(path);

          Widget page = Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    File(path),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              BottomInfoOverlay(
                title: name,
                rounded: false,
                trailing: DesktopCopyButton(
                  filePath: path,
                  iconColor: Colors.white,
                ),
              ),
            ],
          );

          page = DraggableEmojiWrapper(filePath: path, child: page);
          page = SwipeUpToShare(filePath: path, child: page);

          return page;
        },
      ),
    );
  }
}
