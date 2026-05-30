/// 支持的图片扩展名（小写）
const Set<String> kImageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
};

bool isImageFile(String path) {
  final ext = _extension(path);
  return kImageExtensions.contains(ext);
}

bool isGifFile(String path) => _extension(path) == '.gif';

/// 动图 / 不宜生成静态缩略图的格式：封面直接读原文件（GIF 会由系统解码并播放动画）。
bool shouldSkipCoverThumbCache(String path) {
  final ext = _extension(path);
  return ext == '.gif' || ext == '.webp';
}

String _extension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return '';
  return path.substring(dot).toLowerCase();
}
