import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/cover_thumb_cache_service.dart';
import '../services/emoji_constants.dart';
import 'lazy_file_image.dart';

/// 优先显示磁盘缩略图缓存；GIF/WebP 等直接用原文件（Flutter 解码首帧）。
class CachedCoverImage extends StatefulWidget {
  const CachedCoverImage({
    super.key,
    required this.sourcePath,
    required this.decodeSide,
    this.fit = BoxFit.cover,
  });

  final String sourcePath;
  final double decodeSide;
  final BoxFit fit;

  @override
  State<CachedCoverImage> createState() => _CachedCoverImageState();
}

class _CachedCoverImageState extends State<CachedCoverImage> {
  String? _displayPath;
  bool _sourceMissing = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CachedCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourcePath != widget.sourcePath) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final source = widget.sourcePath;

    if (!_fileExists(source)) {
      if (mounted) {
        setState(() {
          _sourceMissing = true;
          _displayPath = null;
        });
      }
      return;
    }

    _sourceMissing = false;

    if (shouldSkipCoverThumbCache(source)) {
      if (mounted) setState(() => _displayPath = source);
      return;
    }

    final cache = context.read<CoverThumbCacheService>();
    final cached = await cache.cachedThumbPath(source);
    if (!mounted) return;
    setState(() => _displayPath = cached ?? source);

    if (cached == null && !_generating) {
      _generating = true;
      final thumb = await cache.ensureThumb(source);
      _generating = false;
      if (!mounted || thumb == null) return;
      setState(() => _displayPath = thumb);
    }
  }

  bool _fileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sourceMissing) {
      return Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: widget.decodeSide * 0.35,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.45),
        ),
      );
    }

    final path = _displayPath ?? widget.sourcePath;
    return LazyFileImage(
      key: ValueKey(path),
      path: path,
      decodeSide: widget.decodeSide,
      fit: widget.fit,
      fallbackPath:
          path != widget.sourcePath ? widget.sourcePath : null,
    );
  }
}
