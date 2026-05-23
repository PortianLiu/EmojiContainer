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

String _extension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return '';
  return path.substring(dot).toLowerCase();
}
