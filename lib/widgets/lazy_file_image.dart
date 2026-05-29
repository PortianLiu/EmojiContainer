import 'dart:io';

import 'package:flutter/material.dart';

import '../services/emoji_constants.dart';

/// 按显示宽度解码本地缩略图（仅 cacheWidth，保持宽高比）
class LazyFileImage extends StatefulWidget {
  const LazyFileImage({
    super.key,
    required this.path,
    required this.decodeSide,
    this.fit = BoxFit.contain,
    this.errorIcon,
    this.placeholderColor,
    this.fallbackPath,
  });

  final String path;
  final double decodeSide;
  final BoxFit fit;
  final Widget? errorIcon;
  final Color? placeholderColor;
  /// 缩略图解码失败时回退原图路径（仅尝试一次）
  final String? fallbackPath;

  @override
  State<LazyFileImage> createState() => _LazyFileImageState();
}

class _LazyFileImageState extends State<LazyFileImage> {
  String? _activePath;
  bool _triedFallback = false;

  @override
  void initState() {
    super.initState();
    _activePath = widget.path;
  }

  @override
  void didUpdateWidget(LazyFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _activePath = widget.path;
      _triedFallback = false;
    }
  }

  void _onError() {
    final fallback = widget.fallbackPath;
    if (!_triedFallback &&
        fallback != null &&
        fallback.isNotEmpty &&
        _activePath != fallback &&
        File(fallback).existsSync()) {
      setState(() {
        _triedFallback = true;
        _activePath = fallback;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _activePath ?? widget.path;
    final bg = widget.placeholderColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final useGifDecode = isGifFile(path);
    final cacheWidth = useGifDecode
        ? null
        : (widget.decodeSide * dpr).round().clamp(48, 768);

    return Image.file(
      File(path),
      fit: widget.fit,
      alignment: Alignment.center,
      gaplessPlayback: true,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.low,
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded || frame != null) return child;
        return ColoredBox(color: bg);
      },
      errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onError());
        return widget.errorIcon ??
            Icon(
              Icons.broken_image_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            );
      },
    );
  }
}
