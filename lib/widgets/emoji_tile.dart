import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/emoji_send_service.dart';
import '../utils/file_name_utils.dart';
import '../utils/platform_utils.dart';
import 'bottom_info_overlay.dart';
import 'desktop_copy_button.dart';
import 'draggable_emoji_wrapper.dart';
import 'lazy_file_image.dart';

class EmojiTile extends StatelessWidget {
  const EmojiTile({
    super.key,
    required this.path,
    required this.decodeSide,
    this.onTap,
    this.onLongPress,
    this.selectable = false,
    this.selected = false,
  });

  final String path;
  final double decodeSide;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selectable;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = fileDisplayName(path);
    final canQuickSend = !selectable && (supportsSystemShare || isDesktop);

    Widget tile = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: colorScheme.surfaceContainerHighest,
              child: Center(
                child: LazyFileImage(
                  path: path,
                  decodeSide: decodeSide,
                  fit: BoxFit.contain,
                  placeholderColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            if (selectable)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? colorScheme.primary : Colors.white70,
                  shadows: const [Shadow(blurRadius: 4)],
                ),
              ),
            if (!selectable)
              BottomInfoOverlay(
                title: name,
                trailing: DesktopCopyButton(filePath: path),
              )
            else if (selected)
              BottomInfoOverlay(title: name),
          ],
        ),
      ),
    );

    if (!selectable) {
      tile = DraggableEmojiWrapper(filePath: path, child: tile);
    }

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        onDoubleTap: canQuickSend
            ? () => context.read<EmojiSendService>().sendWithFeedback(
                  context,
                  path,
                )
            : null,
        child: tile,
      ),
    );
  }
}
