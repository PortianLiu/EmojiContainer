import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:share_plus/share_plus.dart';

import '../bloc/root_directory/root_directory_cubit.dart';
import '../services/storage_permission_service.dart';
import '../utils/android_media_permission.dart';
import '../utils/file_name_utils.dart';
import '../utils/platform_utils.dart';

/// 发送表情：手机调起系统分享，电脑复制到剪贴板
class EmojiSendService {
  /// 执行发送。成功返回 null，失败返回错误信息。
  Future<String?> send(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return '文件不存在';
    }

    try {
      if (supportsSystemShare) {
        // 无 context 时仅检查是否已授权（调用方应事先 requestAccess）
        final permissionError = await ensureAndroidMediaReadPermission();
        if (permissionError != null) return permissionError;
        await _shareFile(filePath);
        return null;
      }
      if (isDesktop) {
        await _copyToClipboard(filePath);
        return null;
      }
      return '当前平台暂不支持发送';
    } catch (e) {
      return '发送失败：$e';
    }
  }

  Future<void> sendWithFeedback(
    BuildContext context,
    String filePath, {
    StoragePermissionService? permissionService,
  }) async {
    if (supportsSystemShare) {
      final root = context.read<RootDirectoryCubit>().state.path;
      final service =
          permissionService ?? context.read<StoragePermissionService>();
      if (!await service.hasAccessForRoot(root)) {
        final granted =
            await service.requestAccess(context, rootPath: root);
        if (!granted) return;
      }
    }
    final error = await send(filePath);
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          supportsSystemShare
              ? '已打开系统分享'
              : '已复制到剪贴板，可在聊天窗口 Ctrl+V 粘贴',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareFile(String filePath) async {
    final name = fileDisplayName(filePath);
    await Share.shareXFiles(
      [XFile(filePath, name: name)],
      text: name,
    );
  }

  Future<void> _copyToClipboard(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    await Pasteboard.writeImage(bytes);
  }
}
