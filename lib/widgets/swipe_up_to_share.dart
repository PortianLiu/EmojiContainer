import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/emoji_send_service.dart';
import '../utils/platform_utils.dart';

/// 手机端大图预览：上滑触发系统分享
class SwipeUpToShare extends StatefulWidget {
  const SwipeUpToShare({
    super.key,
    required this.filePath,
    required this.child,
  });

  final String filePath;
  final Widget child;

  static const double _triggerDistance = 72;

  @override
  State<SwipeUpToShare> createState() => _SwipeUpToShareState();
}

class _SwipeUpToShareState extends State<SwipeUpToShare> {
  double _dragOffset = 0;
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    if (!supportsSystemShare) {
      return widget.child;
    }

    final showHint = _dragOffset < -16;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.translate(
            offset: Offset(0, _dragOffset.clamp(-100.0, 0.0)),
            child: widget.child,
          ),
          if (showHint)
            Positioned(
              left: 0,
              right: 0,
              bottom: 72,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _dragOffset < -SwipeUpToShare._triggerDistance
                        ? '松开分享'
                        : '继续上滑分享',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          if (!showHint)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: Center(
                child: _IdleSwipeHint(),
              ),
            ),
        ],
      ),
    );
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
      if (_dragOffset > 0) _dragOffset = 0;
    });
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final shouldShare =
        _dragOffset < -SwipeUpToShare._triggerDistance || velocity < -600;

    if (shouldShare && !_sharing && mounted) {
      setState(() => _sharing = true);
      await context.read<EmojiSendService>().sendWithFeedback(
            context,
            widget.filePath,
          );
      if (mounted) setState(() => _sharing = false);
    }

    if (mounted) {
      setState(() => _dragOffset = 0);
    }
  }
}

class _IdleSwipeHint extends StatelessWidget {
  const _IdleSwipeHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.keyboard_arrow_up_rounded,
          size: 18,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          '上滑分享',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
