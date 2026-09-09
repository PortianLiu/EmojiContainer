import 'package:flutter/material.dart';

import '../utils/platform_utils.dart';
import 'emoji_share_sheet.dart';

/// 手机端大图预览：上滑触发分享选项
class SwipeUpToShare extends StatefulWidget {
  const SwipeUpToShare({
    super.key,
    required this.filePath,
    required this.child,
    this.albumName,
  });

  final String filePath;
  final Widget child;
  final String? albumName;

  /// 触发分享所需的上滑距离（逻辑像素）
  static const double _triggerDistance = 80;

  /// 触发后图片相对原位向上移动的固定距离（与手指拖拽量无关）
  static const double _glideDistance = 240;

  /// 快速上抛也可触发
  static const double _flingVelocity = -600;

  @override
  State<SwipeUpToShare> createState() => _SwipeUpToShareState();
}

class _SwipeUpToShareState extends State<SwipeUpToShare>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  Animation<double>? _offsetAnim;

  double _dragOffset = 0;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this)
      ..addListener(() {
        final anim = _offsetAnim;
        if (anim == null) return;
        setState(() => _dragOffset = anim.value);
      });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!supportsSystemShare) {
      return widget.child;
    }

    final showHint = _dragOffset < -16 && !_sharing;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _sharing ? null : _onDragUpdate,
      onVerticalDragEnd: _sharing ? null : _onDragEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.translate(
            offset: Offset(0, _dragOffset),
            child: widget.child,
          ),
          if (showHint)
            Positioned(
              left: 0,
              right: 0,
              bottom: 72,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
          if (!showHint && !_sharing)
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
    _anim.stop();
    setState(() {
      _dragOffset += details.delta.dy;
      // 不能拖过固定终点，避免松手后反向回弹
      _dragOffset = _dragOffset.clamp(-SwipeUpToShare._glideDistance, 0.0);
    });
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final shouldShare = _dragOffset < -SwipeUpToShare._triggerDistance ||
        velocity < SwipeUpToShare._flingVelocity;

    if (shouldShare && !_sharing && mounted) {
      setState(() => _sharing = true);
      // 无论手指拖了多远，都滑到相对原位的固定终点
      await _animateTo(
        -SwipeUpToShare._glideDistance,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;

      await presentEmojiShareOptions(
        context,
        widget.filePath,
        albumName: widget.albumName,
      );
      if (!mounted) return;

      await _animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      if (mounted) setState(() => _sharing = false);
      return;
    }

    await _animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _animateTo(
    double target, {
    required Duration duration,
    required Curve curve,
  }) {
    _offsetAnim = Tween<double>(begin: _dragOffset, end: target)
        .animate(CurvedAnimation(parent: _anim, curve: curve));
    _anim.duration = duration;
    return _anim.forward(from: 0);
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
