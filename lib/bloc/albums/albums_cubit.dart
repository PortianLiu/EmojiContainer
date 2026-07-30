import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:io';
import '../../services/album_cache_service.dart';
import '../../services/album_cover_service.dart';
import '../../services/album_group_service.dart';
import '../../services/emoji_repository.dart';
import '../../services/nomedia_service.dart';
import '../../services/preferences_service.dart';
import 'albums_state.dart';

class AlbumsCubit extends Cubit<AlbumsState> {
  AlbumsCubit({
    required EmojiRepository repository,
    AlbumCacheService? cacheService,
    PreferencesService? preferences,
    NomediaService? nomediaService,
    AlbumGroupService? groupService,
    AlbumOrderService? orderService,
  })  : _repository = repository,
        _cache = cacheService ?? AlbumCacheService(),
        _preferences = preferences ?? PreferencesService(),
        _nomedia = nomediaService ?? NomediaService(),
        _groupService = groupService ?? AlbumGroupService(),
        _orderService = orderService ?? AlbumOrderService(),
        super(const AlbumsState());

  final EmojiRepository _repository;
  final AlbumCacheService _cache;
  final PreferencesService _preferences;
  final NomediaService _nomedia;
  final AlbumGroupService _groupService;
  final AlbumOrderService _orderService;
  String? _loadingRoot;
  bool _scanInProgress = false;

  Future<void> load(String rootPath) async {
    if (_loadingRoot == rootPath && _scanInProgress) return;
    _loadingRoot = rootPath;

    final mode = await _preferences.getBrowseMode();
    final coverStyle = await _preferences.getAlbumCoverStyle();
    final nestedSort = await _preferences.getNestedSortOrder();

    if (mode == BrowseMode.flat) {
      final cached = await _cache.loadGroups(rootPath);
      if (cached != null && cached.any((g) => g.albums.isNotEmpty)) {
        emit(
          AlbumsState(
            status: AlbumsStatus.loaded,
            groups: cached,
            browseMode: mode,
            coverStyle: coverStyle,
            nestedSortOrder: nestedSort,
            fromCache: true,
            isRefreshing: true,
          ),
        );
      } else if (state.status != AlbumsStatus.loaded || state.groups.isEmpty) {
        emit(AlbumsState(
          status: AlbumsStatus.loading,
          browseMode: mode,
          coverStyle: coverStyle,
          nestedSortOrder: nestedSort,
        ));
      }
    } else if (state.status != AlbumsStatus.loaded || state.nestedRoot == null) {
      emit(AlbumsState(
        status: AlbumsStatus.loading,
        browseMode: mode,
        coverStyle: coverStyle,
        nestedSortOrder: nestedSort,
      ));
    }

    if (_scanInProgress) return;
    _scanInProgress = true;

    try {
      if (mode == BrowseMode.nested) {
        final nestedRoot = await _repository.loadContents(
          rootPath,
          BrowseMode.nested,
          sortOrder: nestedSort,
        );
        if (_loadingRoot == rootPath) {
          emit(
            AlbumsState(
              status: AlbumsStatus.loaded,
              nestedRoot: nestedRoot,
              browseMode: mode,
              coverStyle: coverStyle,
              nestedSortOrder: nestedSort,
              fromCache: false,
              isRefreshing: false,
            ),
          );
        }
      } else {
        final groups = await _repository.loadGroupedAlbums(
          rootPath,
          mode,
          groupService: _groupService,
          orderService: _orderService,
        );
        // 磁盘始终写入扫描结果（含最新 coverThumbs），下次冷启动生效
        await _cache.saveGroups(rootPath, groups);

        if (Platform.isAndroid && await _preferences.getAutoNomedia()) {
          await _nomedia.ensureNomediaUnder(rootPath);
        }

        if (_loadingRoot == rootPath) {
          // 本次已用缓存/旧列表画过封面时：UI 保留旧 coverThumbs，避免刷新闪换封面
          final keepCovers = state.status == AlbumsStatus.loaded &&
              state.groups.isNotEmpty;
          final uiGroups = keepCovers
              ? AlbumCoverService.preserveDisplayCovers(
                  previous: state.groups,
                  fresh: groups,
                )
              : groups;
          emit(
            AlbumsState(
              status: AlbumsStatus.loaded,
              groups: uiGroups,
              browseMode: mode,
              coverStyle: coverStyle,
              nestedSortOrder: nestedSort,
              fromCache: false,
              isRefreshing: false,
            ),
          );
        }
      }
    } on EmojiRepositoryException catch (e) {
      _emitError(e.message, mode, coverStyle, nestedSort);
    } catch (e) {
      _emitError('加载失败：$e', mode, coverStyle, nestedSort);
    } finally {
      _scanInProgress = false;
    }
  }

  void _emitError(
    String message,
    BrowseMode mode,
    AlbumCoverStyle coverStyle,
    NestedSortOrder nestedSort,
  ) {
    if (state.status == AlbumsStatus.loaded &&
        (!state.isEmpty || state.fromCache)) {
      emit(state.copyWith(
        isRefreshing: false,
        errorMessage: '刷新失败：$message',
      ));
    } else {
      emit(
        AlbumsState(
          status: AlbumsStatus.error,
          errorMessage: message,
          browseMode: mode,
          coverStyle: coverStyle,
          nestedSortOrder: nestedSort,
        ),
      );
    }
  }

  void reset() {
    _loadingRoot = null;
    _scanInProgress = false;
    emit(const AlbumsState());
    _cache.clear();
  }
}
