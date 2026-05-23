/// 单次复制到 camera 的记录（同一表情可有多条、不同时间）
class CameraExportRecord {
  const CameraExportRecord({
    required this.id,
    required this.sourcePath,
    required this.destPath,
    required this.albumName,
    required this.batchFolder,
    required this.batchRootPath,
    required this.storageLocation,
    required this.exportedAt,
  });

  final String id;
  final String sourcePath;
  final String destPath;
  final String albumName;
  final String batchFolder;
  /// 该批次文件所在根目录（用于清理）
  final String batchRootPath;
  /// dcim | app_root
  final String storageLocation;
  final DateTime exportedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourcePath': sourcePath,
        'destPath': destPath,
        'albumName': albumName,
        'batchFolder': batchFolder,
        'batchRootPath': batchRootPath,
        'storageLocation': storageLocation,
        'exportedAt': exportedAt.toIso8601String(),
      };

  factory CameraExportRecord.fromJson(Map<String, dynamic> json) {
    return CameraExportRecord(
      id: json['id'] as String,
      sourcePath: json['sourcePath'] as String,
      destPath: json['destPath'] as String,
      albumName: json['albumName'] as String,
      batchFolder: json['batchFolder'] as String,
      batchRootPath: json['batchRootPath'] as String? ??
          _inferBatchRoot(json['destPath'] as String, json['batchFolder'] as String),
      storageLocation: json['storageLocation'] as String? ?? 'app_root',
      exportedAt: DateTime.parse(json['exportedAt'] as String),
    );
  }

  static String _inferBatchRoot(String destPath, String batchFolder) {
    final normalized = destPath.replaceAll('\\', '/');
    final marker = '/$batchFolder/';
    final i = normalized.indexOf(marker);
    if (i >= 0) {
      return normalized.substring(0, i + marker.length - 1);
    }
    return normalized.substring(0, normalized.lastIndexOf('/'));
  }
}

/// 按批次分组的导出记录
class CameraExportBatch {
  const CameraExportBatch({
    required this.batchFolder,
    required this.exportedAt,
    required this.records,
    required this.batchRootPath,
    required this.storageLocation,
  });

  final String batchFolder;
  final DateTime exportedAt;
  final List<CameraExportRecord> records;
  final String batchRootPath;
  final String storageLocation;

  int get count => records.length;

  String get locationLabel {
    switch (storageLocation) {
      case 'gallery':
        return '系统相册';
      case 'dcim':
        return '系统相册 DCIM/Camera';
      default:
        return '应用目录 camera';
    }
  }

  List<String> get albumNames =>
      records.map((r) => r.albumName).toSet().toList();
}
