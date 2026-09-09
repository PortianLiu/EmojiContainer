import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:share_plus/share_plus.dart';

import '../bloc/root_directory/root_directory_cubit.dart';
import '../models/emoji_export_item.dart';
import 'camera_export_service.dart';
import 'gallery_image_exporter.dart';
import '../utils/android_media_permission.dart';
import '../utils/file_name_utils.dart';
import '../utils/platform_utils.dart';

/// 发送表情：定向/系统分享，或电脑复制到剪贴板
class EmojiSendService {
  static const _shareChannel = MethodChannel('lpt.emoji_container/share');

  static const wechatPackage = 'com.tencent.mm';
  static const qqPackage = 'com.tencent.mobileqq';

  static final Map<String, Uint8List?> _appIconCache = {};

  /// 读取已安装应用图标（Android）；未安装或失败返回 null。
  Future<Uint8List?> getInstalledAppIcon(String packageName) async {
    if (!Platform.isAndroid) return null;
    if (_appIconCache.containsKey(packageName)) {
      return _appIconCache[packageName];
    }
    try {
      final bytes = await _shareChannel.invokeMethod<Uint8List>(
        'getAppIcon',
        {'packageName': packageName},
      );
      _appIconCache[packageName] = bytes;
      return bytes;
    } catch (_) {
      _appIconCache[packageName] = null;
      return null;
    }
  }

  /// 桌面端：复制到剪贴板并提示。手机端请使用 [presentEmojiShareOptions]。
  Future<void> sendWithFeedback(
    BuildContext context,
    String filePath,
  ) async {
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

  /// 执行发送。成功返回 null，失败返回错误信息。
  Future<String?> send(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return '文件不存在';
    }

    try {
      if (supportsSystemShare) {
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

  Future<String?> shareToWeChat(String filePath) => _shareToPackage(
        filePath,
        wechatPackage,
        appLabel: '微信',
        target: 'wechat_friends',
      );

  Future<String?> shareToQQ(String filePath) => _shareToPackage(
        filePath,
        qqPackage,
        appLabel: 'QQ',
        target: 'qq_friends',
      );

  Future<String?> shareSystem(String filePath) async {
    try {
      final permissionError = await ensureAndroidMediaReadPermission();
      if (permissionError != null) return permissionError;
      await _shareFile(filePath);
      return null;
    } catch (e) {
      return '分享失败：$e';
    }
  }

  /// 复制到系统相册（时间置顶）。
  Future<({bool ok, String message})> pinToGallery({
    required BuildContext context,
    required String filePath,
    required String albumName,
  }) async {
    if (useGalleryExport && !await GalleryImageExporter.ensureAccess()) {
      return (ok: false, message: '未获得相册写入权限，无法保存到相册');
    }
    if (!context.mounted) {
      return (ok: false, message: '页面已关闭');
    }

    try {
      final root = context.read<RootDirectoryCubit>().state.path;
      if (root == null) return (ok: false, message: '未设置根目录');
      final exportService = context.read<CameraExportService>();
      final result = await exportService.exportEmojis(
        fallbackRoot: root,
        items: [
          EmojiExportItem(sourcePath: filePath, albumName: albumName),
        ],
      );
      return (ok: true, message: '已复制到 ${result.locationDescription}');
    } on CameraExportException catch (e) {
      return (ok: false, message: e.message);
    } on GalleryExportException catch (e) {
      return (ok: false, message: e.message);
    } catch (e) {
      return (ok: false, message: '复制失败：$e');
    }
  }

  Future<String?> _shareToPackage(
    String filePath,
    String packageName, {
    required String appLabel,
    required String target,
  }) async {
    if (!Platform.isAndroid) {
      return shareSystem(filePath);
    }

    final file = File(filePath);
    if (!await file.exists()) return '文件不存在';

    try {
      final permissionError = await ensureAndroidMediaReadPermission();
      if (permissionError != null) return permissionError;
      await _shareChannel.invokeMethod<void>('shareToPackage', {
        'filePath': filePath,
        'packageName': packageName,
        'target': target,
      });
      return null;
    } on PlatformException catch (e) {
      if (e.code == 'app_not_found') {
        return '未安装$appLabel，或当前无法打开';
      }
      return '分享到$appLabel失败：${e.message ?? e.code}';
    } catch (e) {
      return '分享到$appLabel失败：$e';
    }
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
