import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/albums/albums_cubit.dart';
import 'bloc/root_directory/root_directory_cubit.dart';
import 'bloc/root_directory/root_directory_state.dart';
import 'screens/albums_screen.dart';
import 'screens/root_setup_screen.dart';
import 'services/album_manage_service.dart';
import 'services/camera_export_service.dart';
import 'services/camera_export_store.dart';
import 'services/emoji_import_service.dart';
import 'services/emoji_repository.dart';
import 'services/emoji_send_service.dart';
import 'services/album_cover_service.dart';
import 'services/album_group_service.dart';
import 'services/emoji_delete_service.dart';
import 'services/nomedia_service.dart';
import 'services/preferences_service.dart';
import 'services/storage_permission_service.dart';

class EmojiContainerApp extends StatelessWidget {
  const EmojiContainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => PreferencesService()),
        RepositoryProvider(create: (_) => EmojiRepository()),
        RepositoryProvider(create: (_) => EmojiSendService()),
        RepositoryProvider(create: (_) => StoragePermissionService()),
        RepositoryProvider(create: (_) => CameraExportStore()),
        RepositoryProvider(create: (_) => CameraExportService()),
        RepositoryProvider(create: (_) => AlbumManageService()),
        RepositoryProvider(create: (_) => AlbumCoverService()),
        RepositoryProvider(create: (_) => AlbumOrderService()),
        RepositoryProvider(create: (_) => AlbumGroupService()),
        RepositoryProvider(create: (_) => EmojiDeleteService()),
        RepositoryProvider(create: (_) => NomediaService()),
        RepositoryProvider(
          create: (context) => EmojiImportService(
            storagePermission: context.read<StoragePermissionService>(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => RootDirectoryCubit(
              preferences: context.read<PreferencesService>(),
            )..loadSaved(),
          ),
          BlocProvider(
            create: (context) => AlbumsCubit(
              repository: context.read<EmojiRepository>(),
              preferences: context.read<PreferencesService>(),
              nomediaService: context.read<NomediaService>(),
              groupService: context.read<AlbumGroupService>(),
              orderService: context.read<AlbumOrderService>(),
            ),
          ),
        ],
        child: MaterialApp(
          title: '表情包管理器',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5C6BC0),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(centerTitle: false),
          ),
          home: const _AppShell(),
        ),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  String? _loadedRoot;

  void _startAlbumLoad(String rootPath) {
    if (_loadedRoot == rootPath) return;
    _loadedRoot = rootPath;
    context.read<AlbumsCubit>().load(rootPath);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RootDirectoryCubit, RootDirectoryState>(
      listenWhen: (prev, curr) =>
          curr.hasRoot &&
          curr.status == RootDirectoryStatus.ready &&
          prev.path != curr.path,
      listener: (context, state) {
        final path = state.path;
        if (path != null) _startAlbumLoad(path);
      },
      child: BlocBuilder<RootDirectoryCubit, RootDirectoryState>(
        builder: (context, state) {
          if (state.status == RootDirectoryStatus.loading ||
              state.status == RootDirectoryStatus.initial) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (!state.hasRoot) {
            _loadedRoot = null;
            return const RootSetupScreen();
          }

          final path = state.path;
          if (path != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _startAlbumLoad(path);
            });
          }

          return const AlbumsScreen();
        },
      ),
    );
  }
}
