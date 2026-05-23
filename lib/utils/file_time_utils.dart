import 'dart:io';

/// 同步读取修改时间（扫描时比 async 快很多）
int fileModifiedMillisSync(String path) {
  try {
    return File(path).lastModifiedSync().millisecondsSinceEpoch;
  } catch (_) {
    return 0;
  }
}

/// 按修改时间逆序（新的在前）
void sortPathsByTimeDescSync(List<String> paths) {
  paths.sort(
    (a, b) =>
        fileModifiedMillisSync(b).compareTo(fileModifiedMillisSync(a)),
  );
}
