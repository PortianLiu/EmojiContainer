import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/root_directory/root_directory_cubit.dart';
import '../models/emoji_album.dart';
import '../models/emoji_export_item.dart';
import '../bloc/albums/albums_cubit.dart';
import '../services/album_group_service.dart';
import '../services/camera_export_service.dart';
import '../services/emoji_delete_service.dart';
import '../services/emoji_import_service.dart';
import '../services/nomedia_service.dart';
import '../services/preferences_service.dart';
import '../services/emoji_repository.dart';
import '../services/storage_permission_service.dart';
import '../services/gallery_image_exporter.dart';
import '../utils/delete_confirm.dart';
import '../utils/emoji_image_actions.dart';
import '../utils/file_name_utils.dart';
import '../utils/file_time_utils.dart';
import '../utils/platform_utils.dart';
import '../utils/responsive_grid.dart';
import '../widgets/bottom_info_overlay.dart';
import '../widgets/desktop_copy_button.dart';
import '../widgets/draggable_emoji_wrapper.dart';
import '../widgets/emoji_tile.dart';
import '../widgets/inset_fab.dart';
import '../widgets/nested_browse_grid.dart';
import '../widgets/swipe_up_to_share.dart';

class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({
    super.key,
    required this.album,
    required this.browseMode,
    this.initialPreviewIndex,
  });

  final EmojiAlbum album;
  final BrowseMode browseMode;
  final int? initialPreviewIndex;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  late List<String> _sortedPaths;
  List<EmojiAlbum> _subAlbums = [];
  int _displayCount = 0;
  bool _selectionMode = false;
  final Set<String> _selectedPaths = {};
  bool _exporting = false;
  bool _importing = false;
  bool _deleting = false;
  final Set<String> _selectedSubAlbumPaths = {};
  NestedSortOrder _nestedSortOrder = NestedSortOrder.foldersFirst;
  AlbumCoverStyle _coverStyle = AlbumCoverStyle.grid;

  @override
  void initState() {
    super.initState();
    _sortedPaths = List<String>.from(widget.album.emojiPaths);
    _displayCount = widget.album.count;
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reloadContents().then((_) {
        if (!mounted) return;
        final idx = widget.initialPreviewIndex;
        if (idx != null && idx >= 0 && idx < _sortedPaths.length) {
          _showPreview(_sortedPaths[idx], idx);
        }
      });
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = context.read<PreferencesService>();
    final sort = await prefs.getNestedSortOrder();
    final cover = await prefs.getAlbumCoverStyle();
    if (mounted) {
      setState(() {
        _nestedSortOrder = sort;
        _coverStyle = cover;
      });
    }
  }

  Future<void> _reloadContents() async {
    try {
      final contents = await context.read<EmojiRepository>().loadContents(
            widget.album.path,
            widget.browseMode,
          );
      if (!mounted) return;
      setState(() {
        _sortedPaths
          ..clear()
          ..addAll(contents.emojiPaths);
        sortPathsByTimeDescSync(_sortedPaths);
        _subAlbums = contents.subAlbums;
        _displayCount = contents.count;
      });
    } catch (_) {}
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedPaths.clear();
      _selectedSubAlbumPaths.clear();
    });
  }

  void _onImageChanged() {
    _reloadContents();
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root != null) {
      context.read<AlbumsCubit>().load(root);
    }
  }

  Future<void> _showImageActions(String path) async {
    await showEmojiImageActionSheet(
      context: context,
      imagePath: path,
      albumPath: widget.album.path,
      albumName: widget.album.name,
      remainingAfterDelete: _sortedPaths.length - 1,
      onChanged: () {
        if (!mounted) return;
        _onImageChanged();
        if (_sortedPaths.isEmpty &&
            _subAlbums.isEmpty &&
            widget.browseMode == BrowseMode.nested) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _toggleSubAlbumSelection(String path) {
    setState(() {
      if (_selectedSubAlbumPaths.contains(path)) {
        _selectedSubAlbumPaths.remove(path);
      } else {
        _selectedSubAlbumPaths.add(path);
      }
    });
  }

  int get _selectedTotal =>
      _selectedPaths.length + _selectedSubAlbumPaths.length;

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
          content: Text('已复制 ${result.copiedCount} 张到 ${result.locationDescription}'),
          duration: const Duration(seconds: 2),
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

  Future<void> _deleteSelected() async {
    if (_selectedTotal == 0 || _deleting) return;

    final emojiPaths = _selectedPaths.toList();
    final subPaths = _selectedSubAlbumPaths.toList();
    final deleteService = context.read<EmojiDeleteService>();

    var subAnyHasImages = false;
    for (final path in subPaths) {
      if (await deleteService.albumHasImages(path, widget.browseMode)) {
        subAnyHasImages = true;
        break;
      }
    }

    if (!mounted) return;

    if (emojiPaths.isNotEmpty) {
      final remaining = _sortedPaths.length - emojiPaths.length;
      final ok = await confirmDeleteEmojis(
        context,
        selectedCount: emojiPaths.length,
        remainingAfterDelete: remaining,
      );
      if (!ok) return;
    }

    if (subPaths.isNotEmpty) {
      final ok = await confirmDeleteAlbums(
        context,
        albumCount: subPaths.length,
        anyHasImages: subAnyHasImages,
      );
      if (!ok) return;
    }

    setState(() => _deleting = true);
    try {
      final root = context.read<RootDirectoryCubit>().state.path;
      await deleteService.deleteFiles(emojiPaths);
      for (final path in subPaths) {
        await deleteService.deleteAlbumDirectory(path);
      }
      if (root != null && subPaths.isNotEmpty) {
        await context
            .read<AlbumGroupService>()
            .removeAlbumsFromAllGroups(root, subPaths);
      }

      if (!mounted) return;
      final count = emojiPaths.length + subPaths.length;
      _exitSelectionMode();
      if (root != null) context.read<AlbumsCubit>().load(root);
      await _reloadContents();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除 $count 项'),
          duration: const Duration(seconds: 2),
        ),
      );

      if (_sortedPaths.isEmpty &&
          _subAlbums.isEmpty &&
          widget.browseMode == BrowseMode.nested &&
          mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _refreshLocalPaths() async {
    await _reloadContents();
  }

  Future<void> _importImages() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final result = await context.read<EmojiImportService>().pickAndImport(
            context: context,
            albumPath: widget.album.path,
          );
      if (!mounted) return;
      if (result != null && result.importedCount > 0) {
        final root = context.read<RootDirectoryCubit>().state.path;
        if (root != null) {
          context.read<AlbumsCubit>().load(root);
        }
        await _refreshLocalPaths();
        if (Platform.isAndroid &&
            await context.read<PreferencesService>().getAutoNomedia()) {
          await context
              .read<NomediaService>()
              .ensureNomediaForDirectory(widget.album.path);
        }
        if (!mounted) return;
        final verb = result.mode.actionVerb;
        var message = '已$verb ${result.importedCount} 张';
        if (result.galleryRemoveFailedCount > 0) {
          message +=
              '（${result.galleryRemoveFailedCount} 张仍在相册，已复制到表情包夹）';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on EmojiImportException catch (e) {
      if (mounted) {
        final needsSettings = e.message.contains('权限') ||
            e.message.contains('写入') ||
            e.message.contains('授权');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            duration: Duration(seconds: needsSettings ? 5 : 2),
            action: needsSettings
                ? SnackBarAction(
                    label: '去授权',
                    onPressed: () => context
                        .read<StoragePermissionService>()
                        .openAllFilesAccessSettings(),
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
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
          albumPath: widget.album.path,
        ),
      ),
    );
  }

  void _openSubAlbum(EmojiAlbum sub) {
    if (_selectionMode) {
      _toggleSubAlbumSelection(sub.path);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AlbumDetailScreen(
          album: sub,
          browseMode: widget.browseMode,
        ),
      ),
    ).then((_) => _reloadContents());
  }

  @override
  Widget build(BuildContext context) {
    final mobile = supportsSystemShare;
    final isNested = widget.browseMode == BrowseMode.nested;
    final isEmpty = isNested
        ? _sortedPaths.isEmpty && _subAlbums.isEmpty
        : _sortedPaths.isEmpty;
    final countLabel = isNested
        ? '${_subAlbums.length} 夹 · ${_sortedPaths.length} 张'
        : '$_displayCount 张';

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '已选 $_selectedTotal 项'
              : widget.album.name,
        ),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _exitSelectionMode,
              )
            : null,
        automaticallyImplyLeading: !_selectionMode,
        actions: [
          if (!_selectionMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  countLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          if (!_selectionMode &&
              (_sortedPaths.isNotEmpty ||
                  (isNested && _subAlbums.isNotEmpty)))
            IconButton(
              icon: const Icon(Icons.checklist_outlined),
              tooltip: '选择复制或删除',
              onPressed: () => setState(() => _selectionMode = true),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  mobile
                      ? '点选表情或子文件夹；底部可复制到系统相册或删除'
                      : '点选要删除的表情或子文件夹',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                      ),
                ),
              ),
            )
          else ...[
            if (supportsOutboundDrag) const _DesktopSendHint(),
            Material(
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withValues(alpha: 0.35),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  supportsOutboundDrag
                      ? '双击复制到剪贴板；长按表情可设为封面、复制或删除'
                      : '双击分享；长按表情可设为封面、复制或删除',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                      ),
                ),
              ),
            ),
          ],
          Expanded(
            child: isEmpty
                ? const _EmptyAlbum()
                : isNested
                    ? NestedBrowseGrid(
                        subAlbums: _subAlbums,
                        imagePaths: _sortedPaths,
                        sortOrder: _nestedSortOrder,
                        coverStyle: _coverStyle,
                        selectionMode: _selectionMode,
                        selectedAlbumPaths: _selectedSubAlbumPaths,
                        selectedImagePaths: _selectedPaths,
                        onAlbumTap: _openSubAlbum,
                        onImageTap: _showPreview,
                        onImageLongPress: _showImageActions,
                      )
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
                                onLongPress: () => _showImageActions(path),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _selectionMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    if (mobile) ...[
                      Expanded(
                        child: OutlinedButton.icon(
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
                                : '复制到系统相册 (${_selectedPaths.length})',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _deleting || _selectedTotal == 0
                            ? null
                            : _deleteSelected,
                        icon: _deleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline),
                        label: Text('删除 ($_selectedTotal)'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: mobile && !_selectionMode
          ? InsetFab(
              onPressed: _importing ? null : _importImages,
              tooltip: '从相册导入',
              child: _importing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
            )
          : null,
      ),
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
                '按住表情图片拖动到聊天窗口；双击复制到剪贴板',
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
    required this.albumPath,
  });

  final List<String> paths;
  final int initialIndex;
  final String title;
  final String albumPath;

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
