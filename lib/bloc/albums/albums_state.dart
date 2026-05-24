import '../../models/emoji_album.dart';
import '../../services/preferences_service.dart';

enum AlbumsStatus { initial, loading, loaded, error }

class AlbumsState {
  const AlbumsState({
    this.status = AlbumsStatus.initial,
    this.groups = const [],
    this.nestedRoot,
    this.errorMessage,
    this.fromCache = false,
    this.isRefreshing = false,
    this.browseMode = BrowseMode.flat,
    this.coverStyle = AlbumCoverStyle.grid,
    this.nestedSortOrder = NestedSortOrder.foldersFirst,
  });

  final AlbumsStatus status;
  final List<EmojiAlbumGroup> groups;
  final EmojiAlbumContents? nestedRoot;
  final String? errorMessage;
  final bool fromCache;
  final bool isRefreshing;
  final BrowseMode browseMode;
  final AlbumCoverStyle coverStyle;
  final NestedSortOrder nestedSortOrder;

  List<EmojiAlbum> get albums => groups.expand((g) => g.albums).toList();

  bool get isEmpty {
    if (browseMode == BrowseMode.nested) {
      final root = nestedRoot;
      if (root == null) return true;
      return root.emojiPaths.isEmpty && root.subAlbums.isEmpty;
    }
    return albums.isEmpty;
  }

  AlbumsState copyWith({
    AlbumsStatus? status,
    List<EmojiAlbumGroup>? groups,
    EmojiAlbumContents? nestedRoot,
    String? errorMessage,
    bool? fromCache,
    bool? isRefreshing,
    BrowseMode? browseMode,
    AlbumCoverStyle? coverStyle,
    NestedSortOrder? nestedSortOrder,
    bool clearError = false,
    bool clearNestedRoot = false,
  }) {
    return AlbumsState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      nestedRoot: clearNestedRoot ? null : (nestedRoot ?? this.nestedRoot),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fromCache: fromCache ?? this.fromCache,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      browseMode: browseMode ?? this.browseMode,
      coverStyle: coverStyle ?? this.coverStyle,
      nestedSortOrder: nestedSortOrder ?? this.nestedSortOrder,
    );
  }
}
