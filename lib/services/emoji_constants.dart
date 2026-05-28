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

/// 动图 / 不宜转 JPEG 的格式：封面走原文件，由 Flutter 按尺寸解码首帧。
bool shouldSkipCoverThumbCache(String path) {
  final ext = _extension(path);
  return ext == '.gif' || ext == '.webp';
}

String _extension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return '';
  return path.substring(dot).toLowerCase();
}
