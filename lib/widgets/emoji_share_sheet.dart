import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../bloc/root_directory/root_directory_cubit.dart';
import '../services/emoji_send_service.dart';
import '../services/storage_permission_service.dart';

/// 校验权限后弹出分享选项（微信 / QQ / 时间置顶 / 通用分享）
Future<void> presentEmojiShareOptions(
  BuildContext context,
  String filePath, {
  String? albumName,
  StoragePermissionService? permissionService,
}) async {
  final root = context.read<RootDirectoryCubit>().state.path;
  final service =
      permissionService ?? context.read<StoragePermissionService>();
  if (!await service.hasAccessForRoot(root)) {
    if (!context.mounted) return;
    final granted = await service.requestAccess(context, rootPath: root);
    if (!granted) return;
  }
  if (!context.mounted) return;

  await showEmojiShareSheet(
    context: context,
    filePath: filePath,
    albumName: albumName ?? p.basename(p.dirname(filePath)),
  );
}

/// App 内分享选项：微信 / QQ / 时间置顶 / 通用分享（宫格）
Future<void> showEmojiShareSheet({
  required BuildContext context,
  required String filePath,
  required String albumName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black26,
    isDismissible: true,
    enableDrag: true,
    builder: (sheetContext) {
      final send = context.read<EmojiSendService>();
      final items = <_ShareGridItem>[
        _ShareGridItem(
          icon: Icons.chat_bubble_outline,
          label: '微信好友',
          onTap: () => _runAction(
            rootContext: context,
            sheetContext: sheetContext,
            action: () => send.shareToWeChat(filePath),
            successMessage: '已打开微信分享',
          ),
        ),
        _ShareGridItem(
          icon: Icons.groups_outlined,
          label: 'QQ好友',
          onTap: () => _runAction(
            rootContext: context,
            sheetContext: sheetContext,
            action: () => send.shareToQQ(filePath),
            successMessage: '已打开QQ分享',
          ),
        ),
        _ShareGridItem(
          icon: Icons.push_pin_outlined,
          label: '时间置顶',
          onTap: () async {
            Navigator.pop(sheetContext);
            final result = await send.pinToGallery(
              context: context,
              filePath: filePath,
              albumName: albumName,
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        _ShareGridItem(
          icon: Icons.ios_share_outlined,
          label: '通用分享',
          onTap: () => _runAction(
            rootContext: context,
            sheetContext: sheetContext,
            action: () => send.shareSystem(filePath),
            successMessage: '已打开系统分享',
          ),
        ),
      ];

      final scheme = Theme.of(sheetContext).colorScheme;

      return SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height,
        child: Column(
          children: [
            Expanded(
              child: _OutsideDismissArea(
                onDismiss: () => Navigator.pop(sheetContext),
              ),
            ),
            Material(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: scheme.onSurface.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        '分享到',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.85,
                        children: [
                          for (final item in items) _ShareGridCell(item: item),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// 弹窗外区域：点击或下滑关闭
class _OutsideDismissArea extends StatefulWidget {
  const _OutsideDismissArea({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_OutsideDismissArea> createState() => _OutsideDismissAreaState();
}

class _OutsideDismissAreaState extends State<_OutsideDismissArea> {
  double _dragDy = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      onVerticalDragUpdate: (details) {
        _dragDy += details.delta.dy;
      },
      onVerticalDragEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond.dy;
        if (_dragDy > 48 || velocity > 400) {
          widget.onDismiss();
        }
        _dragDy = 0;
      },
      onVerticalDragCancel: () => _dragDy = 0,
      child: const SizedBox.expand(),
    );
  }
}

class _ShareGridItem {
  const _ShareGridItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ShareGridCell extends StatelessWidget {
  const _ShareGridCell({required this.item});

  final _ShareGridItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, size: 26, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

Future<void> _runAction({
  required BuildContext rootContext,
  required BuildContext sheetContext,
  required Future<String?> Function() action,
  required String successMessage,
}) async {
  Navigator.pop(sheetContext);
  final error = await action();
  if (!rootContext.mounted) return;
  ScaffoldMessenger.of(rootContext).showSnackBar(
    SnackBar(
      content: Text(error ?? successMessage),
      duration: const Duration(seconds: 2),
    ),
  );
}
