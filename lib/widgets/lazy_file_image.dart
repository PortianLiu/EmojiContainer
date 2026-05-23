import 'dart:io';

import 'package:flutter/material.dart';

/// 按显示宽度解码本地缩略图（仅 cacheWidth，保持宽高比）
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
    final cacheWidth = (decodeSide * dpr).round().clamp(48, 768);

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
