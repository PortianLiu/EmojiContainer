import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/album_cache_service.dart';
import '../../services/emoji_repository.dart';
import 'albums_state.dart';

class AlbumsCubit extends Cubit<AlbumsState> {
  AlbumsCubit({
    required EmojiRepository repository,
    AlbumCacheService? cacheService,
  })  : _repository = repository,
        _cache = cacheService ?? AlbumCacheService(),
        super(const AlbumsState());

  final EmojiRepository _repository;
  final AlbumCacheService _cache;
  String? _loadingRoot;
  bool _scanInProgress = false;

  /// 启动：先读缓存立即展示，再后台扫描（不重复触发）
  Future<void> load(String rootPath) async {
    if (_loadingRoot == rootPath && _scanInProgress) return;
    _loadingRoot = rootPath;

    final cached = await _cache.load(rootPath);
    if (cached != null && cached.isNotEmpty) {
      emit(
        AlbumsState(
          status: AlbumsStatus.loaded,
          albums: cached,
          fromCache: true,
          isRefreshing: true,
        ),
      );
    } else if (state.status != AlbumsStatus.loaded || state.albums.isEmpty) {
      emit(const AlbumsState(status: AlbumsStatus.loading));
    }

    if (_scanInProgress) return;
    _scanInProgress = true;

    try {
      final albums = await _repository.loadAlbums(rootPath);
      await _cache.save(rootPath, albums);
      if (_loadingRoot == rootPath) {
        emit(
          AlbumsState(
            status: AlbumsStatus.loaded,
            albums: albums,
            fromCache: false,
            isRefreshing: false,
          ),
        );
      }
    } on EmojiRepositoryException catch (e) {
      if (cached != null && cached.isNotEmpty) {
        emit(
          AlbumsState(
            status: AlbumsStatus.loaded,
            albums: cached,
            fromCache: true,
            isRefreshing: false,
            errorMessage: '刷新失败：${e.message}',
          ),
        );
      } else {
        emit(
          AlbumsState(
            status: AlbumsStatus.error,
            errorMessage: e.message,
          ),
        );
      }
    } catch (e) {
      if (cached != null && cached.isNotEmpty) {
        emit(
          AlbumsState(
            status: AlbumsStatus.loaded,
            albums: cached,
            fromCache: true,
            isRefreshing: false,
            errorMessage: '刷新失败：$e',
          ),
        );
      } else {
        emit(
          AlbumsState(
            status: AlbumsStatus.error,
            errorMessage: '加载失败：$e',
          ),
        );
      }
    } finally {
      _scanInProgress = false;
    }
  }

  void reset() {
    _loadingRoot = null;
    _scanInProgress = false;
    emit(const AlbumsState());
    _cache.clear();
  }
}
