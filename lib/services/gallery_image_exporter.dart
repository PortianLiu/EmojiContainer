import 'dart:io';

import 'package:gal/gal.dart';

/// 通过系统 MediaStore 保存到相册（Android 对应 DCIM/Camera）
class GalleryImageExporter {
  static const dcimCameraPath = '/storage/emulated/0/DCIM/Camera';

  static Future<bool> ensureAccess() async {
    if (await Gal.hasAccess()) return true;
    return Gal.requestAccess();
  }

  /// 保存到系统相机相册（DCIM/Camera），不使用自定义 album 名
  static Future<void> saveToDcimCamera(String sourcePath) async {
    try {
      await Gal.putImage(sourcePath);
    } on GalException catch (e) {
      throw GalleryExportException(e.type.message);
    }
  }
}

class GalleryExportException implements Exception {
  GalleryExportException(this.message);
  final String message;

  @override
  String toString() => message;
}

bool get useGalleryExport => Platform.isAndroid || Platform.isIOS;
