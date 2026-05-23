import 'package:flutter/material.dart';

import '../services/storage_permission_service.dart';

Future<String?> ensureAndroidMediaReadPermission([
  BuildContext? context,
  String? rootPath,
]) async {
  final service = StoragePermissionService();
  if (await service.hasAccessForRoot(rootPath)) return null;
  if (context == null) {
    return '需要「允许访问所有文件」权限才能读取表情包文件夹';
  }
  return service.ensureAccess(context, rootPath: rootPath);
}
