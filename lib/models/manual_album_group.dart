/// 用户手动创建的分组（仅平铺模式）
class ManualAlbumGroup {
  const ManualAlbumGroup({
    required this.id,
    required this.name,
    required this.albumPaths,
  });

  final String id;
  final String name;
  final List<String> albumPaths;

  ManualAlbumGroup copyWith({
    String? id,
    String? name,
    List<String>? albumPaths,
  }) {
    return ManualAlbumGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      albumPaths: albumPaths ?? this.albumPaths,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'albumPaths': albumPaths,
      };

  factory ManualAlbumGroup.fromJson(Map<String, dynamic> json) {
    return ManualAlbumGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      albumPaths: List<String>.from(json['albumPaths'] as List),
    );
  }
}
