import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/album_cover_service.dart';
import '../services/emoji_delete_service.dart';
import '../services/emoji_send_service.dart';
import '../utils/delete_confirm.dart';
import '../utils/platform_utils.dart';

/// 表情包夹内长按单张图片：设为封面 / 图片时间置顶 / 删除
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
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('图片时间置顶（copy）'),
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
  final result = await context.read<EmojiSendService>().pinToGallery(
        context: context,
        filePath: imagePath,
        albumName: albumName,
      );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result.message),
      duration: const Duration(seconds: 2),
    ),
  );
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
