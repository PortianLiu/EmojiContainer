import 'dart:io';

import 'package:flutter/services.dart';

/// Windows 原生文件拖出（CF_HDROP，可拖到微信等）
class DesktopFileDragService {
  static const _channel = MethodChannel('emoji_container/file_drag');

  static Future<bool> startDrag(String filePath) async {
    if (!Platform.isWindows) return false;
    final file = File(filePath);
    if (!await file.exists()) return false;

    try {
      final ok = await _channel.invokeMethod<bool>('startDrag', {
        'path': filePath,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }
}
