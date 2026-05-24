import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/root_directory/root_directory_cubit.dart';
import '../models/emoji_export_item.dart';
import '../services/album_cover_service.dart';
import '../services/camera_export_service.dart';
import '../services/emoji_delete_service.dart';
import '../services/gallery_image_exporter.dart';
import '../utils/delete_confirm.dart';
import '../utils/platform_utils.dart';

/// 表情包夹内长按单张图片：设为封面 / 复制到相册 / 删除
Future<void> showEmojiImageActionSheet({
  required BuildContext context,
  required String imagePath,
  required String albumPath,
  required String albumName,
  required VoidCallback onChanged,
  int remainingAfterDelete = 0,
}) async {
  final mobile = supportsSystemShare;

  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('设为封面'),
            onTap: () async {
              Navigator.pop(ctx);
              await context.read<AlbumCoverService>().setCustomCover(
                    albumPath,
                    imagePath,
                  );
              if (!context.mounted) return;
              onChanged();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已设为封面'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          if (mobile)
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('复制到系统相册'),
              onTap: () async {
                Navigator.pop(ctx);
                await _copyOneToGallery(
                  context: context,
                  imagePath: imagePath,
                  albumName: albumName,
                );
              },
            ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(ctx).colorScheme.error,
            ),
            title: Text(
              '删除',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              await _deleteOne(
                context: context,
                imagePath: imagePath,
                remainingAfterDelete: remainingAfterDelete,
                onChanged: onChanged,
              );
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _copyOneToGallery({
  required BuildContext context,
  required String imagePath,
  required String albumName,
}) async {
  if (useGalleryExport && !await GalleryImageExporter.ensureAccess()) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('未获得相册写入权限，无法保存到相册')),
    );
    return;
  }

  try {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;
    final result = await context.read<CameraExportService>().exportEmojis(
          fallbackRoot: root,
          items: [
            EmojiExportItem(sourcePath: imagePath, albumName: albumName),
          ],
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制到 ${result.locationDescription}'),
        duration: const Duration(seconds: 2),
      ),
    );
  } on CameraExportException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  } on GalleryExportException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('复制失败：$e')),
      );
    }
  }
}

Future<void> _deleteOne({
  required BuildContext context,
  required String imagePath,
  required int remainingAfterDelete,
  required VoidCallback onChanged,
}) async {
  final ok = await confirmDeleteEmojis(
    context,
    selectedCount: 1,
    remainingAfterDelete: remainingAfterDelete,
  );
  if (!ok || !context.mounted) return;

  await context.read<EmojiDeleteService>().deleteFiles([imagePath]);
  if (!context.mounted) return;
  onChanged();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('已删除'),
      duration: Duration(seconds: 2),
    ),
  );
}
