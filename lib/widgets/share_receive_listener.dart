import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../bloc/albums/albums_cubit.dart';
import '../bloc/root_directory/root_directory_cubit.dart';
import '../bloc/root_directory/root_directory_state.dart';
import '../models/emoji_album.dart';
import '../services/album_cover_service.dart';
import '../services/emoji_constants.dart';
import '../services/emoji_repository.dart';
import '../services/nomedia_service.dart';
import '../services/preferences_service.dart';
import '../services/share_import_service.dart';
import '../services/storage_permission_service.dart';

/// Android：监听系统分享的图片，弹出表情包夹选择并导入。
class ShareReceiveListener extends StatefulWidget {
  const ShareReceiveListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<ShareReceiveListener> createState() => _ShareReceiveListenerState();
}

class _ShareReceiveListenerState extends State<ShareReceiveListener> {
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  List<String>? _pendingPaths;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;

    ReceiveSharingIntent.instance.getInitialMedia().then(_onSharedMedia);
    _shareSub =
        ReceiveSharingIntent.instance.getMediaStream().listen(_onSharedMedia);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  void _onSharedMedia(List<SharedMediaFile> files) {
    final paths = files
        .where(_isImageMedia)
        .map((f) => f.path)
        .where((p) => p.isNotEmpty)
        .toList();
    if (paths.isEmpty) return;

    _pendingPaths = paths;
    _tryHandlePending();
  }

  bool _isImageMedia(SharedMediaFile file) {
    if (file.type == SharedMediaType.image) return true;
    final path = file.path.toLowerCase();
    return isImageFile(path);
  }

  void _tryHandlePending() {
    if (!Platform.isAndroid || _handling || _pendingPaths == null) return;

    final rootState = context.read<RootDirectoryCubit>().state;
    if (!rootState.hasRoot ||
        rootState.status != RootDirectoryStatus.ready ||
        rootState.path == null) {
      return;
    }

    final paths = _pendingPaths!;
    _pendingPaths = null;
    _handling = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _handling = false;
        return;
      }
      await _showAlbumPicker(paths, rootState.path!);
      _handling = false;
      ReceiveSharingIntent.instance.reset();
    });
  }

  Future<void> _showAlbumPicker(List<String> paths, String rootPath) async {
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    List<EmojiAlbum> albums;
    try {
      albums = await context.read<EmojiRepository>().loadFlatAlbumsOrdered(
            rootPath,
            orderService: context.read<AlbumOrderService>(),
          );
    } catch (e) {
      _showSnack('无法加载表情包夹：$e');
      return;
    }

    if (albums.isEmpty) {
      _showSnack('请先创建表情包夹，再接收分享的图片');
      return;
    }

    if (!navContext.mounted) return;

    final selected = await showModalBottomSheet<EmojiAlbum>(
      context: navContext,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ShareAlbumPickerSheet(
        albums: albums,
        imageCount: paths.length,
      ),
    );

    if (selected == null || !mounted) return;

    final storage = context.read<StoragePermissionService>();
    final writeErr = await storage.ensureWriteAccess(
      navContext,
      targetPath: selected.path,
    );
    if (writeErr != null) {
      _showSnack(writeErr);
      return;
    }

    if (!mounted) return;

    try {
      final result = await context.read<ShareImportService>().importPaths(
            sourcePaths: paths,
            albumPath: selected.path,
          );

      if (Platform.isAndroid &&
          await context.read<PreferencesService>().getAutoNomedia()) {
        await context
            .read<NomediaService>()
            .ensureNomediaForDirectory(selected.path);
      }

      context.read<AlbumsCubit>().load(rootPath);

      _showSnack('已将 ${result.importedCount} 张图片添加到「${selected.name}」');
    } on ShareImportException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('导入失败：$e');
    }
  }

  void _showSnack(String message) {
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RootDirectoryCubit, RootDirectoryState>(
      listenWhen: (prev, curr) =>
          curr.hasRoot &&
          curr.status == RootDirectoryStatus.ready &&
          _pendingPaths != null,
      listener: (_, __) => _tryHandlePending(),
      child: widget.child,
    );
  }
}

class _ShareAlbumPickerSheet extends StatelessWidget {
  const _ShareAlbumPickerSheet({
    required this.albums,
    required this.imageCount,
  });

  final List<EmojiAlbum> albums;
  final int imageCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.65;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '选择表情包夹',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '将 $imageCount 张分享图片添加到',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: albums.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final album = albums[i];
                  return ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(album.name),
                    subtitle: Text('${album.count} 张'),
                    onTap: () => Navigator.pop(ctx, album),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
