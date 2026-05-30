import 'dart:io';

import 'package:flutter/material.dart';

import '../services/emoji_constants.dart';

/// 本地图片：按 [decodeSide] 与屏幕密度计算 [cacheWidth]，避免按原图全尺寸解码。
/// 首页封面与夹内网格均使用本组件；GIF 不限制 cacheWidth 以保留动画。
class LazyFileImage extends StatelessWidget {
  const LazyFileImage({
    super.key,
    required this.path,
    required this.decodeSide,
    this.fit = BoxFit.contain,
    this.errorIcon,
    this.placeholderColor,
  });

  final String path;
  final double decodeSide;
  final BoxFit fit;
  final Widget? errorIcon;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    final bg = placeholderColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = isGifFile(path)
        ? null
        : (decodeSide * dpr).round().clamp(48, 768);

    return Image.file(
      File(path),
      fit: fit,
      alignment: Alignment.center,
      gaplessPlayback: true,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.low,
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded || frame != null) return child;
        return ColoredBox(color: bg);
      },
      errorBuilder: (_, __, ___) =>
          errorIcon ??
          Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}
