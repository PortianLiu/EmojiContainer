import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/camera_export_record.dart';
import '../models/emoji_export_item.dart';
import 'camera_export_store.dart';
import 'camera_path_resolver.dart';
import 'gallery_image_exporter.dart';

class CameraExportResult {
  const CameraExportResult({
    required this.batchFolder,
    required this.copiedCount,
    required this.batchRootPath,
    required this.locationDescription,
    required this.storageLocation,
  });

  final String batchFolder;
  final int copiedCount;
  final String batchRootPath;
  final String locationDescription;
  final CameraStorageLocation storageLocation;
}

class CameraExportService {
  CameraExportService({
    CameraExportStore? store,
    CameraPathResolver? pathResolver,
  })  : _store = store ?? CameraExportStore(),
        _pathResolver = pathResolver ?? CameraPathResolver();

  final CameraExportStore _store;
  final CameraPathResolver _pathResolver;

  static const batchDirPrefix = 'emoji_';

  Future<CameraExportResult> exportEmojis({
    required String fallbackRoot,
    required List<EmojiExportItem> items,
  }) async {
    if (items.isEmpty) {
      throw CameraExportException('请至少选择一张表情');
    }

    if (useGalleryExport) {
      return _exportViaGallery(items);
    }
    return _exportViaFileCopy(fallbackRoot: fallbackRoot, items: items);
  }

  Future<CameraExportResult> _exportViaGallery(
    List<EmojiExportItem> items,
  ) async {
    if (!await GalleryImageExporter.ensureAccess()) {
      throw CameraExportException('未获得相册写入权限');
    }

    final batchFolder = '$batchDirPrefix${_batchFolderName(DateTime.now())}';
    final exportedAt = DateTime.now();
    final records = <CameraExportRecord>[];
    var index = 0;

    for (final item in items) {
      final src = File(item.sourcePath);
      if (!await src.exists()) continue;

      final assetId = await GalleryImageExporter.saveToGallery(item.sourcePath);
      final name = p.basename(item.sourcePath);

      records.add(
        CameraExportRecord(
          id: '${exportedAt.millisecondsSinceEpoch}_${index++}',
          sourcePath: item.sourcePath,
          destPath: 'gallery:$batchFolder/$name',
          albumName: item.albumName,
          batchFolder: batchFolder,
          batchRootPath: 'gallery:$batchFolder',
          storageLocation: 'gallery',
          exportedAt: exportedAt,
          galleryAssetId: assetId,
        ),
      );
    }

    if (records.isEmpty) {
      throw CameraExportException('所选文件均不存在或无法保存到相册');
    }

    await _store.addRecords(records);

    return CameraExportResult(
      batchFolder: batchFolder,
      copiedCount: records.length,
      batchRootPath: 'gallery:$batchFolder',
      locationDescription: '系统相册（Pictures）',
      storageLocation: CameraStorageLocation.dcim,
    );
  }

  Future<CameraExportResult> _exportViaFileCopy({
    required String fallbackRoot,
    required List<EmojiExportItem> items,
  }) async {
    final pathResult = await _pathResolver.resolve(fallbackRoot: fallbackRoot);
    final batchFolder = '$batchDirPrefix${_batchFolderName(DateTime.now())}';
    final batchDir = Directory(p.join(pathResult.basePath, batchFolder));
    await batchDir.create(recursive: true);

    final exportedAt = DateTime.now();
    final records = <CameraExportRecord>[];
    var index = 0;

    for (final item in items) {
      final src = File(item.sourcePath);
      if (!await src.exists()) continue;

      final destPath = await _uniqueDestPath(
        batchDir.path,
        p.basename(item.sourcePath),
      );
      await src.copy(destPath);

      records.add(
        CameraExportRecord(
          id: '${exportedAt.millisecondsSinceEpoch}_${index++}',
          sourcePath: item.sourcePath,
          destPath: destPath,
          albumName: item.albumName,
          batchFolder: batchFolder,
          batchRootPath: batchDir.path,
          storageLocation: 'dcim',
          exportedAt: exportedAt,
        ),
      );
    }

    if (records.isEmpty) {
      throw CameraExportException('所选文件均不存在或无法复制');
    }

    await _store.addRecords(records);

    return CameraExportResult(
      batchFolder: batchFolder,
      copiedCount: records.length,
      batchRootPath: batchDir.path,
      locationDescription: pathResult.description,
      storageLocation: pathResult.location,
    );
  }

  Future<List<CameraExportBatch>> loadBatches() => _store.loadBatches();

  Future<int> cleanupBatch({
    required String batchFolder,
    String? batchRootPath,
  }) async {
    final records = await _store.loadAll();
    final batchRecords =
        records.where((r) => r.batchFolder == batchFolder).toList();

    final assetIds = batchRecords
        .map((r) => r.galleryAssetId)
        .whereType<String>()
        .toList();

    if (assetIds.isNotEmpty) {
      await GalleryImageExporter.deleteByAssetIds(assetIds);
    }

    final root = batchRootPath ??
        (batchRecords.isNotEmpty ? batchRecords.first.batchRootPath : null);

    if (root != null &&
        !root.startsWith('gallery:') &&
        !root.startsWith('dcim:')) {
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }

    final removed = batchRecords.length;
    await _store.removeByBatch(batchFolder);
    return removed;
  }

  Future<int> cleanupAll() async {
    final all = await _store.loadAll();
    final assetIds =
        all.map((r) => r.galleryAssetId).whereType<String>().toList();
    if (assetIds.isNotEmpty) {
      await GalleryImageExporter.deleteByAssetIds(assetIds);
    }

    final roots = all
        .map((r) => r.batchRootPath)
        .where((r) => !r.startsWith('gallery:') && !r.startsWith('dcim:'))
        .toSet();

    for (final root in roots) {
      final dir = Directory(root);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }

    final count = all.length;
    await _store.clearAll();
    return count;
  }

  String _batchFolderName(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '${y}${m}${d}_$h$min$s';
  }

  Future<String> _uniqueDestPath(String dir, String fileName) async {
    var dest = p.join(dir, fileName);
    if (!await File(dest).exists()) return dest;

    final ext = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    var n = 1;
    while (await File(dest).exists()) {
      dest = p.join(dir, '${base}_$n$ext');
      n++;
    }
    return dest;
  }
}

class CameraExportException implements Exception {
  CameraExportException(this.message);
  final String message;

  @override
  String toString() => message;
}
