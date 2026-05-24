import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

/// 通过 MediaStore 保存到系统相册，并返回 Asset ID 供删除
class GalleryImageExporter {
  static Future<bool> ensureAccess() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state.hasAccess;
  }

  static Future<String> saveToGallery(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw GalleryExportException('源文件不存在');
    }

    final entity = await PhotoManager.editor.saveImageWithPath(
      sourcePath,
      title: sourcePath.split(Platform.pathSeparator).last,
    );

    return entity.id;
  }

  static Future<int> deleteByAssetIds(List<String> assetIds) async {
    if (assetIds.isEmpty) return 0;
    final deleted = await PhotoManager.editor.deleteWithIds(assetIds);
    return deleted.length;
  }
}

class GalleryExportException implements Exception {
  GalleryExportException(this.message);
  final String message;

  @override
  String toString() => message;
}

bool get useGalleryExport => Platform.isAndroid || Platform.isIOS;
