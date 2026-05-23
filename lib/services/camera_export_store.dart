import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/camera_export_record.dart';

/// 持久化 Camera 导出记录
class CameraExportStore {
  static const _fileName = 'camera_export_records.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<List<CameraExportRecord>> loadAll() async {
    final file = await _file();
    if (!await file.exists()) return [];

    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return [];
      final list = jsonDecode(text) as List<dynamic>;
      return list
          .map((e) => CameraExportRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<CameraExportRecord> records) async {
    final file = await _file();
    final encoded = jsonEncode(records.map((r) => r.toJson()).toList());
    await file.writeAsString(encoded);
  }

  Future<void> addRecords(List<CameraExportRecord> added) async {
    final all = await loadAll();
    all.addAll(added);
    all.sort((a, b) => b.exportedAt.compareTo(a.exportedAt));
    await saveAll(all);
  }

  Future<List<CameraExportBatch>> loadBatches() async {
    final all = await loadAll();
    final map = <String, List<CameraExportRecord>>{};
    for (final r in all) {
      map.putIfAbsent(r.batchFolder, () => []).add(r);
    }

    final batches = map.entries.map((e) {
      e.value.sort((a, b) => b.exportedAt.compareTo(a.exportedAt));
      final first = e.value.first;
      return CameraExportBatch(
        batchFolder: e.key,
        exportedAt: first.exportedAt,
        records: e.value,
        batchRootPath: first.batchRootPath,
        storageLocation: first.storageLocation,
      );
    }).toList();

    batches.sort((a, b) => b.exportedAt.compareTo(a.exportedAt));
    return batches;
  }

  Future<void> removeByBatch(String batchFolder) async {
    final all = await loadAll();
    all.removeWhere((r) => r.batchFolder == batchFolder);
    await saveAll(all);
  }

  Future<void> clearAll() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 某源文件被导出过的次数
  Future<int> countExportsForSource(String sourcePath) async {
    final all = await loadAll();
    return all.where((r) => r.sourcePath == sourcePath).length;
  }
}
