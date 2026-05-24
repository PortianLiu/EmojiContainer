import 'package:flutter/material.dart';

/// 底部文字条：贴边半透明黑底，仅覆盖文字区域高度
class BottomInfoOverlay extends StatelessWidget {
  const BottomInfoOverlay({
    super.key,
    required this.title,
    this.subtitle,
    this.rounded = true,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  /// 保留参数以兼容调用方；遮罩本身不做圆角
  final bool rounded;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
