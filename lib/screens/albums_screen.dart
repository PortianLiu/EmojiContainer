import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/albums/albums_cubit.dart';
import '../bloc/albums/albums_state.dart';
import '../bloc/root_directory/root_directory_cubit.dart';
import '../models/emoji_album.dart';
import '../services/album_cover_service.dart';
import '../services/album_group_service.dart';
import '../services/album_manage_service.dart';
import '../services/emoji_delete_service.dart';
import '../services/preferences_service.dart';
import '../services/storage_permission_service.dart';
import '../utils/delete_confirm.dart';
import '../utils/platform_utils.dart';
import '../widgets/inset_fab.dart';
import '../widgets/nested_browse_grid.dart';
import '../widgets/reorderable_album_grid.dart';
import 'album_detail_screen.dart';
import 'camera_export_history_screen.dart';
import 'group_manage_screen.dart';
import 'settings_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedAlbumPaths = {};
  bool _deleting = false;

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedAlbumPaths.clear();
    });
  }

  void _toggleAlbumSelection(String path) {
    setState(() {
      if (_selectedAlbumPaths.contains(path)) {
        _selectedAlbumPaths.remove(path);
      } else {
        _selectedAlbumPaths.add(path);
      }
    });
  }

  Future<void> _reloadAlbums() async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;
    context.read<AlbumsCubit>().load(root);
  }

  Future<void> _saveAlbumOrder(List<EmojiAlbum> albums) async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;
    await context.read<AlbumOrderService>().saveOrder(
          root,
          albums.map((a) => a.path).toList(),
        );
    if (mounted) context.read<AlbumsCubit>().load(root);
  }

  void _enterSelectionWithAlbum(EmojiAlbum album) {
    setState(() {
      _selectionMode = true;
      _selectedAlbumPaths.add(album.path);
    });
  }

  Future<void> _fixDirectoryAccess() async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;
    final permission = context.read<StoragePermissionService>();
    final ok = await permission.requestAccess(context, rootPath: root);
    if (ok && mounted) {
      context.read<AlbumsCubit>().load(root);
    }
  }

  Future<void> _editRootPath() async {
    final rootCubit = context.read<RootDirectoryCubit>();
    final current = rootCubit.state.path ?? '';
    final controller = TextEditingController(text: current);

  final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改总目录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '目录路径',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final path = await FilePicker.platform.getDirectoryPath(
                  dialogTitle: '选择表情包总目录',
                );
                if (path != null) {
                  controller.text = path;
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('浏览选择文件夹'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final path = controller.text.trim();
    if (path.isEmpty) return;

    final permission = context.read<StoragePermissionService>();
    if (!await permission.ensureManageStorageBeforePick(context)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未获得「所有文件访问」权限，无法切换目录'),
        ),
      );
      return;
    }
    if (!mounted) return;

    if (!await permission.canReadDirectory(path)) {
      if (!mounted) return;
      final ok = await permission.requestAccess(context, rootPath: path);
      if (!ok || !mounted) return;
    }

    if (!mounted) return;
    await rootCubit.setPath(path);
    if (mounted) await _reloadAlbums();
  }

  Future<void> _deleteSelectedAlbums(BrowseMode browseMode) async {
    if (_selectedAlbumPaths.isEmpty || _deleting) return;

    final paths = _selectedAlbumPaths.toList();
    final deleteService = context.read<EmojiDeleteService>();
    var anyHasImages = false;
    for (final path in paths) {
      if (await deleteService.albumHasImages(path, browseMode)) {
        anyHasImages = true;
        break;
      }
    }

    if (!mounted) return;
    final confirmed = await confirmDeleteAlbums(
      context,
      albumCount: paths.length,
      anyHasImages: anyHasImages,
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      final root = context.read<RootDirectoryCubit>().state.path;
      if (root == null) return;

      for (final path in paths) {
        await deleteService.deleteAlbumDirectory(path);
      }
      await context.read<AlbumGroupService>().removeAlbumsFromAllGroups(root, paths);

      if (!mounted) return;
      final count = paths.length;
      _exitSelectionMode();
      await _reloadAlbums();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除 $count 个表情包夹'),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _assignSelectedToGroup() async {
    if (_selectedAlbumPaths.isEmpty) return;
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;

    final groupService = context.read<AlbumGroupService>();
    final groups = await groupService.loadGroups(root);
    if (!mounted) return;

    final groupId = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('新建分组并加入'),
              onTap: () async {
                Navigator.pop(ctx, '__new__');
              },
            ),
            const Divider(height: 1),
            ...groups.map(
              (g) => ListTile(
                leading: const Icon(Icons.folder_special_outlined),
                title: Text(g.name),
                subtitle: Text('${g.albumPaths.length} 个表情包夹'),
                onTap: () => Navigator.pop(ctx, g.id),
              ),
            ),
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('暂无分组，可新建一个'),
              ),
          ],
        ),
      ),
    );

    if (groupId == null || !mounted) return;

    if (groupId == '__new__') {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('新建分组'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '分组名称',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('创建'),
            ),
          ],
        ),
      );
      if (ok != true || controller.text.trim().isEmpty || !mounted) return;
      final g = await groupService.createGroup(root, controller.text);
      await groupService.assignAlbumsToGroup(root, g.id, _selectedAlbumPaths.toList());
    } else {
      await groupService.assignAlbumsToGroup(
        root,
        groupId,
        _selectedAlbumPaths.toList(),
      );
    }

    if (!mounted) return;
    _exitSelectionMode();
    await _reloadAlbums();
  }

  Future<void> _createAlbum() async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;

    final nameController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建表情包夹'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '文件夹名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await context.read<AlbumManageService>().createAlbum(
            rootPath: root,
            name: nameController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('表情包夹已创建'),
            duration: Duration(seconds: 2),
          ),
        );
        await _reloadAlbums();
      }
    } on AlbumManageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rootPath = context.watch<RootDirectoryCubit>().state.path ?? '';
    final mobile = supportsSystemShare;

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectionMode) _exitSelectionMode();
      },
      child: BlocBuilder<AlbumsCubit, AlbumsState>(
        builder: (context, albumsState) {
          final flatMode = albumsState.browseMode == BrowseMode.flat;

          return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode
            ? '已选 ${_selectedAlbumPaths.length} 个'
            : '表情包'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _exitSelectionMode,
              )
            : null,
        automaticallyImplyLeading: !_selectionMode,
        actions: [
          if (!_selectionMode && flatMode)
            IconButton(
              icon: const Icon(Icons.folder_special_outlined),
              tooltip: '管理分组',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GroupManageScreen(),
                  ),
                ).then((_) => _reloadAlbums());
              },
            ),
          if (!_selectionMode && mobile)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: '导出记录',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CameraExportHistoryScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _reloadAlbums,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : InsetFab(
        onPressed: _createAlbum,
        tooltip: '新建表情包夹',
        child: const Icon(Icons.create_new_folder_outlined),
      ),
      bottomNavigationBar: _selectionMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    if (flatMode) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectedAlbumPaths.isEmpty
                              ? null
                              : _assignSelectedToGroup,
                          icon: const Icon(Icons.drive_file_move_outline),
                          label: const Text('加入分组'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _deleting || _selectedAlbumPaths.isEmpty
                            ? null
                            : () => _deleteSelectedAlbums(albumsState.browseMode),
                        icon: _deleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline),
                        label: const Text('删除'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RootPathBanner(path: rootPath, onTap: _editRootPath),
          BlocBuilder<AlbumsCubit, AlbumsState>(
            buildWhen: (prev, curr) =>
                prev.isRefreshing != curr.isRefreshing ||
                prev.fromCache != curr.fromCache,
            builder: (context, state) {
              if (!state.isRefreshing) return const SizedBox.shrink();
              return const LinearProgressIndicator(minHeight: 2);
            },
          ),
          if (supportsOutboundDrag && !_selectionMode) const _DesktopSendHint(),
          if (!_selectionMode)
            Material(
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withValues(alpha: 0.35),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  flatMode
                      ? '长按拖拽可调整顺序；双击可选择、删除或加入分组'
                      : '双击表情包夹可选择、删除',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                      ),
                ),
              ),
            ),
          Expanded(
            child: BlocBuilder<AlbumsCubit, AlbumsState>(
              builder: (context, state) {
                switch (state.status) {
                  case AlbumsStatus.initial:
                  case AlbumsStatus.loading:
                    return const Center(child: CircularProgressIndicator());
                  case AlbumsStatus.error:
                    return _ErrorView(
                      message: state.errorMessage ?? '加载失败',
                      onRetry: _reloadAlbums,
                    );
                  case AlbumsStatus.loaded:
                    if (state.isEmpty) {
                      return _EmptyAlbumsView(
                        onFixAccess: _fixDirectoryAccess,
                        onEditRoot: _editRootPath,
                      );
                    }
                    if (state.browseMode == BrowseMode.nested) {
                      final root = state.nestedRoot!;
                      return NestedBrowseGrid(
                        subAlbums: root.subAlbums,
                        imagePaths: root.emojiPaths,
                        sortOrder: state.nestedSortOrder,
                        coverStyle: state.coverStyle,
                        selectionMode: _selectionMode,
                        selectedAlbumPaths: _selectedAlbumPaths,
                        onAlbumTap: (album) {
                          if (_selectionMode) {
                            _toggleAlbumSelection(album.path);
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AlbumDetailScreen(
                                album: album,
                                browseMode: BrowseMode.nested,
                              ),
                            ),
                          ).then((_) => _reloadAlbums());
                        },
                        onAlbumDoubleTap: _enterSelectionWithAlbum,
                        onImageTap: (path, index) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AlbumDetailScreen(
                                album: EmojiAlbum(
                                  name: root.name,
                                  path: root.path,
                                  emojiPaths: root.emojiPaths,
                                ),
                                browseMode: BrowseMode.nested,
                                initialPreviewIndex: index,
                              ),
                            ),
                          ).then((_) => _reloadAlbums());
                        },
                      );
                    }
                    return ReorderableAlbumGrid(
                      groups: state.groups,
                      coverStyle: state.coverStyle,
                      selectionMode: _selectionMode,
                      selectedPaths: _selectedAlbumPaths,
                      onReorder: _saveAlbumOrder,
                      onAlbumTap: (album) {
                        if (_selectionMode) {
                          _toggleAlbumSelection(album.path);
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AlbumDetailScreen(
                              album: album,
                              browseMode: state.browseMode,
                            ),
                          ),
                        ).then((_) => _reloadAlbums());
                      },
                      onAlbumDoubleTap: _enterSelectionWithAlbum,
                    );
                }
              },
            ),
          ),
        ],
      ),
          );
        },
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

class _RootPathBanner extends StatelessWidget {
  const _RootPathBanner({required this.path, required this.onTap});

  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.folder,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAlbumsView extends StatelessWidget {
  const _EmptyAlbumsView({
    required this.onFixAccess,
    required this.onEditRoot,
  });

  final VoidCallback onFixAccess;
  final VoidCallback onEditRoot;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('暂无表情包集', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '若目录里本来有图却显示为空，请开启「允许访问所有文件」。\n'
              '也可点顶部路径栏检查总目录是否正确。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onFixAccess,
              icon: const Icon(Icons.security),
              label: const Text('开启文件访问权限'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onEditRoot,
              icon: const Icon(Icons.folder_open),
              label: const Text('修改总目录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
