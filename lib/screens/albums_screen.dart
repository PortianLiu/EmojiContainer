import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/albums/albums_cubit.dart';
import '../bloc/albums/albums_state.dart';
import '../bloc/root_directory/root_directory_cubit.dart';
import '../models/emoji_album.dart';
import '../services/storage_permission_service.dart';
import '../utils/platform_utils.dart';
import '../utils/responsive_grid.dart';
import '../widgets/album_card.dart';
import 'album_detail_screen.dart';
import 'camera_export_history_screen.dart';
import 'root_setup_screen.dart';

/// 相册列表主页：类似手机相册展示各个表情包集
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  Future<void> _reloadAlbums() async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;

    context.read<AlbumsCubit>().load(root);
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

  Future<void> _changeRootDirectory() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => const _ChangeRootSheet(),
    );

    if (!mounted) return;

    if (result == 'browse') {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择表情包总目录',
      );
      if (path != null) {
        await context.read<RootDirectoryCubit>().setPath(path);
        if (!mounted) return;
        final permission = context.read<StoragePermissionService>();
        if (!await permission.canReadDirectory(path)) {
          await permission.requestAccess(context, rootPath: path);
        }
        if (mounted) await _reloadAlbums();
      }
    } else if (result == 'input') {
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const RootSetupScreen()),
      );
      if (context.read<RootDirectoryCubit>().state.hasRoot) {
        _reloadAlbums();
      }
    } else if (result == 'clear') {
      context.read<AlbumsCubit>().reset();
      await context.read<RootDirectoryCubit>().clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rootState = context.watch<RootDirectoryCubit>().state;
    final rootPath = rootState.path ?? '';
    final mobile = supportsSystemShare;

    return Scaffold(
      appBar: AppBar(
        title: const Text('表情包'),
        actions: [
          if (mobile)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Camera 导出记录',
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
            tooltip: '更改总目录',
            onPressed: _changeRootDirectory,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RootPathBanner(path: rootPath),
          BlocBuilder<AlbumsCubit, AlbumsState>(
            buildWhen: (prev, curr) =>
                prev.isRefreshing != curr.isRefreshing ||
                prev.fromCache != curr.fromCache,
            builder: (context, state) {
              if (!state.isRefreshing) return const SizedBox.shrink();
              return const LinearProgressIndicator(minHeight: 2);
            },
          ),
          if (supportsOutboundDrag) const _DesktopSendHint(),
          if (supportsSystemShare) const _MobileLongPressHint(),
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
                    if (state.albums.isEmpty) {
                      return _EmptyAlbumsView(
                        onChangeRoot: _changeRootDirectory,
                        onFixAccess: _fixDirectoryAccess,
                      );
                    }
                    return _AlbumsGrid(
                      albums: state.albums,
                      onAlbumTap: (album) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AlbumDetailScreen(album: album),
                          ),
                        );
                      },
                    );
                }
              },
            ),
          ),
        ],
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
                '长按表情分享；进入表情包后点右上角列表可多选复制到 Camera',
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

class _RootPathBanner extends StatelessWidget {
  const _RootPathBanner({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
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
          ],
        ),
      ),
    );
  }
}

class _AlbumsGrid extends StatelessWidget {
  const _AlbumsGrid({
    required this.albums,
    required this.onAlbumTap,
  });

  final List<EmojiAlbum> albums;
  final void Function(EmojiAlbum album) onAlbumTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final decodeSide = albumCellSide(constraints.maxWidth);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          scrollCacheExtent: ScrollCacheExtent.pixels(decodeSide * 2),
          gridDelegate: albumGridDelegate(constraints.maxWidth),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return AlbumCard(
              album: album,
              decodeSide: decodeSide,
              onTap: () => onAlbumTap(album),
            );
          },
        );
      },
    );
  }
}

class _EmptyAlbumsView extends StatelessWidget {
  const _EmptyAlbumsView({
    required this.onChangeRoot,
    required this.onFixAccess,
  });

  final VoidCallback onChangeRoot;
  final VoidCallback onFixAccess;

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
            Text(
              '暂无表情包集',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '若目录里本来有图却显示为空，多半是未开启「允许访问所有文件」。\n'
              '这与相册权限不同，请点下方按钮去系统设置开启。',
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
              onPressed: onChangeRoot,
              icon: const Icon(Icons.folder_open),
              label: const Text('更改总目录'),
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

class _ChangeRootSheet extends StatelessWidget {
  const _ChangeRootSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('浏览选择文件夹'),
            onTap: () => Navigator.pop(context, 'browse'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('手动输入路径'),
            onTap: () => Navigator.pop(context, 'input'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text(
              '清除并重新设置',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => Navigator.pop(context, 'clear'),
          ),
        ],
      ),
    );
  }
}
