import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/emoji_send_service.dart';
import '../utils/platform_utils.dart';

/// 电脑端：小图标复制到剪贴板（用于标题右侧）
class DesktopCopyButton extends StatelessWidget {
  const DesktopCopyButton({
    super.key,
    required this.filePath,
    this.iconColor,
  });

  final String filePath;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      return const SizedBox.shrink();
    }

    return IconButton(
      onPressed: () => context.read<EmojiSendService>().sendWithFeedback(
            context,
            filePath,
          ),
      icon: Icon(
        Icons.content_copy_rounded,
        size: 18,
        color: iconColor ?? Colors.white,
      ),
      tooltip: '复制到剪贴板',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
    );
  }
}
