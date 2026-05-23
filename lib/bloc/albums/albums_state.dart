import '../../models/emoji_album.dart';

enum AlbumsStatus { initial, loading, loaded, error }

class AlbumsState {
  const AlbumsState({
    this.status = AlbumsStatus.initial,
    this.albums = const [],
    this.errorMessage,
    this.fromCache = false,
    this.isRefreshing = false,
  });

  final AlbumsStatus status;
  final List<EmojiAlbum> albums;
  final String? errorMessage;
  /// 当前列表是否来自磁盘缓存（后台正在刷新时为 true）
  final bool fromCache;
  final bool isRefreshing;

  AlbumsState copyWith({
    AlbumsStatus? status,
    List<EmojiAlbum>? albums,
    String? errorMessage,
    bool? fromCache,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return AlbumsState(
      status: status ?? this.status,
      albums: albums ?? this.albums,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fromCache: fromCache ?? this.fromCache,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
