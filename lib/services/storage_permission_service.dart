import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android 读取自选目录 / 写入相册 的权限
class StoragePermissionService {
  /// 能否读取指定目录（以实际访问为准，不只看相册权限）
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

  /// 是否可读表情包根目录；未设置根目录时视为 true（桌面端）
  Future<bool> hasAccessForRoot(String? rootPath) async {
    if (!Platform.isAndroid) return true;
    if (rootPath == null || rootPath.isEmpty) return true;
    return canReadDirectory(rootPath);
  }

  /// 兼容旧调用：有根目录时按目录探测，否则 true
  Future<bool> hasAccess({String? rootPath}) =>
      hasAccessForRoot(rootPath);

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

    if (!context.mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('需要文件访问权限'),
        content: Text(
          rootPath != null && rootPath.isNotEmpty
              ? '读取您选择的表情包文件夹：\n$rootPath\n\n'
                  '请在系统设置中为本应用开启「允许访问所有文件」'
                  '（或「所有文件访问权限」）。\n\n'
                  '这与「相册/照片」权限不同；仅授权相册无法读取该文件夹。'
              : '请选择表情包文件夹，并在系统设置中允许访问所有文件。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    await _requestAllFilesAccess();

    if (rootPath != null && rootPath.isNotEmpty) {
      return canReadDirectory(rootPath);
    }
    return _checkManageStorageGranted();
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

  Future<void> _requestAllFilesAccess() async {
    final sdk = await _androidSdkInt();
    if (sdk != null && sdk >= 30) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    } else {
      await Permission.storage.request();
    }
    await openAppSettings();
  }

  Future<bool> _checkManageStorageGranted() async {
    final sdk = await _androidSdkInt();
    if (sdk != null && sdk >= 30) {
      return Permission.manageExternalStorage.isGranted;
    }
    return Permission.storage.isGranted;
  }

  Future<int?> _androidSdkInt() async {
    if (!Platform.isAndroid) return null;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }
}
