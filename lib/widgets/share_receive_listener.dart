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

class _ShareReceiveListenerState extends State<ShareReceiveListener>
    with WidgetsBindingObserver {
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  List<String>? _pendingPaths;
  bool _handling = false;
  int _retryCount = 0;
  static const _maxRetries = 40;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!Platform.isAndroid) return;

    _shareSub =
        ReceiveSharingIntent.instance.getMediaStream().listen(_onSharedMedia);
    _pollInitialShare();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      _pollInitialShare();
      _scheduleRetry();
    }
  }

  Future<void> _pollInitialShare() async {
    for (var i = 0; i < 25; i++) {
      if (!mounted) return;
      try {
        final media = await ReceiveSharingIntent.instance.getInitialMedia();
        if (media.isNotEmpty) {
          _onSharedMedia(media);
          return;
        }
      } catch (_) {}
      await Future.delayed(Duration(milliseconds: 80 + i * 40));
    }
  }

  void _onSharedMedia(List<SharedMediaFile> files) {
    final paths = files
        .where(_isImageMedia)
        .map((f) => f.path)
        .where((p) => p.isNotEmpty)
        .toList();
    if (paths.isEmpty) return;

    _pendingPaths = paths;
    _retryCount = 0;
    _scheduleRetry(immediate: true);
  }

  bool _isImageMedia(SharedMediaFile file) {
    if (file.type == SharedMediaType.image) return true;
    final path = file.path.toLowerCase();
    return isImageFile(path);
  }

  void _scheduleRetry({bool immediate = false}) {
    if (_pendingPaths == null || _handling) return;
    final delay = immediate
        ? Duration.zero
        : Duration(milliseconds: 150 + _retryCount * 80);
    Future.delayed(delay, () {
      if (mounted) _tryHandlePending();
    });
  }

  void _tryHandlePending() {
    if (!Platform.isAndroid || _handling || _pendingPaths == null) return;

    final rootState = context.read<RootDirectoryCubit>().state;
    if (!rootState.hasRoot || rootState.path == null) {
      if (_retryCount == 0) {
        _showSnack('请先设置表情包总目录，再接收分享的图片');
      }
      _retryLater();
      return;
    }

    if (rootState.status != RootDirectoryStatus.ready) {
      _retryLater();
      return;
    }

    final nav = widget.navigatorKey.currentState;
    if (nav == null || !nav.mounted) {
      _retryLater();
      return;
    }

    final paths = List<String>.from(_pendingPaths!);
    _pendingPaths = null;
    _handling = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _showAlbumPicker(paths, rootState.path!);
      } finally {
        _handling = false;
      }
    });
  }

  void _retryLater() {
    if (_pendingPaths == null) return;
    if (_retryCount >= _maxRetries) {
      _showSnack('无法打开分享界面，请从桌面启动应用后重试');
      _pendingPaths = null;
      return;
    }
    _retryCount++;
    _scheduleRetry();
  }

  Future<void> _showAlbumPicker(List<String> paths, String rootPath) async {
    final nav = widget.navigatorKey.currentState;
    if (nav == null || !nav.mounted) {
      _pendingPaths = paths;
      _retryLater();
      return;
    }

    final overlayContext = nav.overlay?.context ?? nav.context;

    List<EmojiAlbum> albums;
    try {
      albums = await context.read<EmojiRepository>().loadFlatAlbumsOrdered(
            rootPath,
            orderService: context.read<AlbumOrderService>(),
          );
    } catch (e) {
      _pendingPaths = paths;
      _showSnack('无法加载表情包夹：$e');
      _retryLater();
      return;
    }

    if (albums.isEmpty) {
      _pendingPaths = null;
      _showSnack('请先创建表情包夹，再接收分享的图片');
      return;
    }

    if (!overlayContext.mounted) {
      _pendingPaths = paths;
      _retryLater();
      return;
    }

    final selected = await showModalBottomSheet<EmojiAlbum>(
      context: overlayContext,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (ctx) => _ShareAlbumPickerSheet(
        albums: albums,
        imageCount: paths.length,
      ),
    );

    if (selected == null) {
      await ReceiveSharingIntent.instance.reset();
      return;
    }

    if (!mounted) return;

    final writeErr = await context.read<StoragePermissionService>().ensureWriteAccess(
          overlayContext,
          targetPath: selected.path,
        );
    if (writeErr != null) {
      _pendingPaths = paths;
      _showSnack(writeErr);
      return;
    }

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

      if (mounted) {
        context.read<AlbumsCubit>().load(rootPath);
      }

      _showSnack('已将 ${result.importedCount} 张图片添加到「${selected.name}」');
      await ReceiveSharingIntent.instance.reset();
    } on ShareImportException catch (e) {
      _pendingPaths = paths;
      _showSnack(e.message);
    } catch (e) {
      _pendingPaths = paths;
      _showSnack('导入失败：$e');
    }
  }

  void _showSnack(String message) {
    final nav = widget.navigatorKey.currentState;
    final ctx = nav?.overlay?.context ?? nav?.context;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RootDirectoryCubit, RootDirectoryState>(
      listenWhen: (prev, curr) =>
          _pendingPaths != null &&
          curr.hasRoot &&
          curr.status == RootDirectoryStatus.ready &&
          (prev.status != RootDirectoryStatus.ready ||
              prev.path != curr.path),
      listener: (_, __) {
        _retryCount = 0;
        _scheduleRetry(immediate: true);
      },
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
