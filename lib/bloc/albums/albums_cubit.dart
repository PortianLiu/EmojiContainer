import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:async';
import 'dart:io';
import '../../models/emoji_album.dart';
import '../../services/album_cache_service.dart';
import '../../services/album_cover_service.dart';
import '../../services/cover_thumb_cache_service.dart';
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
    CoverThumbCacheService? coverThumbCache,
  })  : _repository = repository,
        _cache = cacheService ?? AlbumCacheService(),
        _preferences = preferences ?? PreferencesService(),
        _nomedia = nomediaService ?? NomediaService(),
        _groupService = groupService ?? AlbumGroupService(),
        _orderService = orderService ?? AlbumOrderService(),
        _coverThumbs = coverThumbCache ?? CoverThumbCacheService(),
        super(const AlbumsState());

  final EmojiRepository _repository;
  final AlbumCacheService _cache;
  final PreferencesService _preferences;
  final NomediaService _nomedia;
  final AlbumGroupService _groupService;
  final AlbumOrderService _orderService;
  final CoverThumbCacheService _coverThumbs;
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
        _warmCoverThumbs(cached.expand((g) => g.albums).toList(), coverStyle);
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
          _warmCoverThumbs(
            [nestedRoot.toAlbum(), ...nestedRoot.subAlbums],
            coverStyle,
          );
        }
      } else {
        final groups = await _repository.loadGroupedAlbums(
          rootPath,
          mode,
          groupService: _groupService,
          orderService: _orderService,
        );
        await _cache.saveGroups(rootPath, groups);

        if (Platform.isAndroid && await _preferences.getAutoNomedia()) {
          await _nomedia.ensureNomediaUnder(rootPath);
        }

        if (_loadingRoot == rootPath) {
          emit(
            AlbumsState(
              status: AlbumsStatus.loaded,
              groups: groups,
              browseMode: mode,
              coverStyle: coverStyle,
              nestedSortOrder: nestedSort,
              fromCache: false,
              isRefreshing: false,
            ),
          );
          _warmCoverThumbs(
            groups.expand((g) => g.albums).toList(),
            coverStyle,
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

  void _warmCoverThumbs(List<EmojiAlbum> albums, AlbumCoverStyle style) {
    if (albums.isEmpty) return;
    unawaited(_coverThumbs.warmAlbums(albums, coverStyle: style));
  }
}
