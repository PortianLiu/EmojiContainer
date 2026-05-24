import 'package:flutter/material.dart';

/// 删除前确认：目标文件夹/夹内无表情时不弹窗
Future<bool> confirmDeleteEmojis(
  BuildContext context, {
  required int selectedCount,
  required int remainingAfterDelete,
}) async {
  if (remainingAfterDelete <= 0) return true;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除表情'),
      content: Text('确定删除选中的 $selectedCount 张表情？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return result == true;
}

Future<bool> confirmDeleteAlbums(
  BuildContext context, {
  required int albumCount,
  required bool anyHasImages,
}) async {
  if (!anyHasImages) return true;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除表情包夹'),
      content: Text(
        albumCount == 1
            ? '选中的表情包夹内仍有表情，确定删除文件夹及其内容？'
            : '选中的 $albumCount 个表情包夹内仍有表情，确定删除？',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return result == true;
}
