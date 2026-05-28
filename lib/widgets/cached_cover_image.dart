import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/cover_thumb_cache_service.dart';
import 'lazy_file_image.dart';

/// 优先显示磁盘缩略图缓存，无缓存时回退原图并按 [decodeSide] 解码。
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
  String? _loadedFor;

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
    _loadedFor = source;
    final cache = context.read<CoverThumbCacheService>();
    final cached = await cache.cachedThumbPath(source);
    if (!mounted || _loadedFor != source) return;
    setState(() => _displayPath = cached ?? source);
    if (cached != null) return;

    final generated = await cache.ensureThumb(source);
    if (!mounted || _loadedFor != source) return;
    if (generated != null) {
      setState(() => _displayPath = generated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _displayPath ?? widget.sourcePath;
    return LazyFileImage(
      path: path,
      decodeSide: widget.decodeSide,
      fit: widget.fit,
    );
  }
}
