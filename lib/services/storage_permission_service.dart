import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

/// Android 读取/写入自选目录的权限（需「允许访问所有文件」，不是相册权限）
class StoragePermissionService {
  static const _channel = MethodChannel('lpt.emoji_container/storage');

  /// 能否读取指定目录（以实际访问为准）
  Future<bool> canReadDirectory(String path) async {
    if (!Platform.isAndroid) return true;
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return false;
      await dir.list(followLinks: false).take(1).toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 能否写入指定目录（写入探针文件验证）
  Future<bool> canWriteDirectory(String path) async {
    if (!Platform.isAndroid) return true;
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probe = File(p.join(path, '.emoji_write_probe'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 是否可读表情包根目录；未设置根目录时视为 true（桌面端）
  Future<bool> hasAccessForRoot(String? rootPath) async {
    if (!Platform.isAndroid) return true;
    if (rootPath == null || rootPath.isEmpty) return true;
    return canReadDirectory(rootPath);
  }

  /// 兼容旧调用：有根目录时按目录探测，否则 true
  Future<bool> hasAccess({String? rootPath}) =>
      hasAccessForRoot(rootPath);

  /// 系统是否已授予「所有文件访问」（Android 11+）
  Future<bool> isManageExternalStorageGranted() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _androidSdkInt();
    if (sdk == null || sdk < 30) {
      return Permission.storage.isGranted;
    }
    try {
      final native = await _channel.invokeMethod<bool>('isExternalStorageManager');
      if (native != null) return native;
    } catch (_) {}
    return Permission.manageExternalStorage.isGranted;
  }

  /// 选目录前调用：没有「所有文件访问」则引导去授权
  Future<bool> ensureManageStorageBeforePick(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    if (await isManageExternalStorageGranted()) return true;
    if (!context.mounted) return false;
    return requestAccess(context);
  }

  /// 申请读取自选目录所需权限
  Future<bool> requestAccess(
    BuildContext context, {
    String? rootPath,
  }) async {
    if (!Platform.isAndroid) return true;

    if (rootPath != null &&
        rootPath.isNotEmpty &&
        await canReadDirectory(rootPath)) {
      return true;
    }

    if (await isManageExternalStorageGranted()) {
      if (rootPath == null || rootPath.isEmpty) return true;
      return canReadDirectory(rootPath);
    }

    if (!context.mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('需要「所有文件访问」权限'),
        content: Text(
          rootPath != null && rootPath.isNotEmpty
              ? '读取您选择的表情包文件夹：\n$rootPath\n\n'
                  '请开启「允许访问所有文件 / 管理所有文件」。\n'
                  '注意：这与「照片和视频 / 相册」权限不同；'
                  '只开相册权限无法读取该文件夹。'
              : '选择表情包文件夹前，请先开启「允许访问所有文件」。\n'
                  '注意：不是「照片和视频」权限。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去授权'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    await openAllFilesAccessSettings();

    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('完成授权后继续'),
        content: const Text(
          '请在系统页中找到本应用，打开「允许访问所有文件」开关，'
          '然后返回并点击「已完成」。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('已完成'),
          ),
        ],
      ),
    );

    if (rootPath != null && rootPath.isNotEmpty) {
      return canReadDirectory(rootPath);
    }
    return isManageExternalStorageGranted();
  }

  Future<String?> ensureAccess(
    BuildContext context, {
    String? rootPath,
  }) async {
    if (!Platform.isAndroid) return null;
    if (await hasAccessForRoot(rootPath)) return null;

    final granted = await requestAccess(context, rootPath: rootPath);
    if (granted) return null;
    return '无法读取表情包文件夹，请在系统设置中开启「允许访问所有文件」';
  }

  /// 确保可向目标文件夹写入；失败时弹出授权引导
  Future<String?> ensureWriteAccess(
    BuildContext context, {
    required String targetPath,
  }) async {
    if (!Platform.isAndroid) return null;
    if (await canWriteDirectory(targetPath)) return null;

    if (!context.mounted) {
      return '无法写入文件夹，请开启「允许访问所有文件」权限';
    }

    final ok = await requestAccess(context, rootPath: targetPath);
    if (ok && await canWriteDirectory(targetPath)) return null;
    return '仍无法写入文件夹，请确认已开启「允许访问所有文件」后重试';
  }

  /// 打开 Android「所有文件访问」授权页（优先原生 Intent，适配小米等）
  Future<void> openAllFilesAccessSettings() async {
    if (!Platform.isAndroid) return;

    final sdk = await _androidSdkInt();
    if (sdk != null && sdk >= 30) {
      try {
        await _channel.invokeMethod<void>('openManageAllFilesSettings');
        return;
      } catch (_) {
        // 回退 permission_handler
      }
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return;
      await openAppSettings();
      return;
    }

    if (!await Permission.storage.isGranted) {
      await Permission.storage.request();
    }
    if (!await Permission.storage.isGranted) {
      await openAppSettings();
    }
  }

  Future<int?> _androidSdkInt() async {
    if (!Platform.isAndroid) return null;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }
}
