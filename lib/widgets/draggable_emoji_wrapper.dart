import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/desktop_file_drag_service.dart';
import '../utils/platform_utils.dart';

/// 电脑端：将表情文件拖放到外部应用（Windows 原生 OLE 拖拽）
class DraggableEmojiWrapper extends StatefulWidget {
  const DraggableEmojiWrapper({
    super.key,
    required this.filePath,
    required this.child,
  });

  final String filePath;
  final Widget child;

  @override
  State<DraggableEmojiWrapper> createState() => _DraggableEmojiWrapperState();
}

class _DraggableEmojiWrapperState extends State<DraggableEmojiWrapper> {
  Offset? _pressOrigin;
  bool _dragStarted = false;

  @override
  Widget build(BuildContext context) {
    if (!supportsOutboundDrag) {
      return widget.child;
    }

    if (Platform.isWindows) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          if (e.buttons == kPrimaryButton) {
            _pressOrigin = e.position;
            _dragStarted = false;
          }
        },
        onPointerMove: (e) {
          if (_dragStarted || _pressOrigin == null) return;
          if ((e.position - _pressOrigin!).distance < 12) return;
          _dragStarted = true;
          DesktopFileDragService.startDrag(widget.filePath);
        },
        onPointerUp: (_) {
          _pressOrigin = null;
          _dragStarted = false;
        },
        onPointerCancel: (_) {
          _pressOrigin = null;
          _dragStarted = false;
        },
        child: widget.child,
      );
    }

    // macOS / Linux：暂用鼠标拖拽提示，可复制后粘贴
    return widget.child;
  }
}
