import 'dart:io';

/// 从文件路径提取显示名（不含扩展名）
String fileDisplayName(String path) {
  final sep = Platform.pathSeparator;
  var name = path;
  final i = path.lastIndexOf(sep);
  if (i >= 0) {
    name = path.substring(i + 1);
  }
  final dot = name.lastIndexOf('.');
  if (dot > 0) {
    return name.substring(0, dot);
  }
  return name;
}
