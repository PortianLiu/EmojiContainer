import 'dart:io';

import 'package:path/path.dart' as p;

enum CameraStorageLocation {
  dcim,
  appRoot,
}

class CameraPathResult {
  const CameraPathResult({
    required this.basePath,
    required this.location,
    required this.description,
  });

  final String basePath;
  final CameraStorageLocation location;
  final String description;
}

/// 桌面端解析 DCIM/Camera；移动端由 Gal/MediaStore 写入，不走此路径
class CameraPathResolver {
  Future<CameraPathResult> resolve({required String fallbackRoot}) async {
    if (Platform.isIOS) {
      throw UnsupportedError('iOS 应使用系统相册 API 导出');
    }

    if (Platform.isAndroid) {
      final dcim = await _tryDcimCamera();
      if (dcim != null) {
        return CameraPathResult(
          basePath: dcim,
          location: CameraStorageLocation.dcim,
          description: dcim,
        );
      }
      throw StateError('无法访问 DCIM/Camera');
    }

    final dcim = await _tryDcimCamera();
    if (dcim != null) {
      return CameraPathResult(
        basePath: dcim,
        location: CameraStorageLocation.dcim,
        description: dcim,
      );
    }

    return CameraPathResult(
      basePath: p.join(fallbackRoot, 'DCIM', 'Camera'),
      location: CameraStorageLocation.dcim,
      description: p.join(fallbackRoot, 'DCIM', 'Camera'),
    );
  }

  Future<String?> _tryDcimCamera() async {
    final candidates = <String>[
      p.join('/storage', 'emulated', '0', 'DCIM', 'Camera'),
      p.join('/storage', 'emulated', '0', 'DCIM', 'camera'),
    ];

    for (final path in candidates) {
      if (await _ensureWritableDir(path)) return path;
    }
    return null;
  }

  Future<bool> _ensureWritableDir(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final testFile = File(p.join(path, '.emoji_container_probe'));
      await testFile.writeAsString('ok');
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
