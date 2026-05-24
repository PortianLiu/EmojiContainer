import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'preferences_service.dart';
import 'storage_permission_service.dart';

class EmojiImportResult {
  const EmojiImportResult({
    required this.importedCount,
    required this.mode,
    this.galleryRemoveFailedCount = 0,
  });

  final int importedCount;
  final ImportMode mode;
  final int galleryRemoveFailedCount;
}

class _ImportOneResult {
  const _ImportOneResult({
    required this.written,
    this.galleryRemoveFailed = false,
  });

  final bool written;
  final bool galleryRemoveFailed;
}

class EmojiImportService {
  EmojiImportService({
    PreferencesService? preferences,
    StoragePermissionService? storagePermission,
  })  : _preferences = preferences ?? PreferencesService(),
        _storagePermission = storagePermission ?? StoragePermissionService();

  final PreferencesService _preferences;
  final StoragePermissionService _storagePermission;

  Future<EmojiImportResult?> pickAndImport({
    required BuildContext context,
    required String albumPath,
  }) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      throw EmojiImportException('需要相册权限才能导入图片');
    }

    if (!context.mounted) return null;

    final writeErr = await _storagePermission.ensureWriteAccess(
      context,
      targetPath: albumPath,
    );
    if (writeErr != null) {
      throw EmojiImportException(writeErr);
    }

    if (!context.mounted) return null;

    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 99,
        requestType: RequestType.image,
      ),
    );

    if (assets == null || assets.isEmpty) return null;

    final albumDir = Directory(albumPath);
    if (!await albumDir.exists()) {
      await albumDir.create(recursive: true);
    }

    final mode = await _preferences.getImportMode();
    final move = mode == ImportMode.cut;
    var count = 0;
    var galleryFailed = 0;
    Object? lastError;

    for (final asset in assets) {
      try {
        final result = await _importOneAsset(
          asset: asset,
          albumPath: albumPath,
          move: move,
        );
        if (result.written) count++;
        if (result.galleryRemoveFailed) galleryFailed++;
      } catch (e) {
        lastError = e;
      }
    }

    if (count == 0) {
      throw EmojiImportException(
        lastError != null
            ? '导入失败：$lastError'
            : '未能导入任何图片，请确认已开启「允许访问所有文件」',
      );
    }

    return EmojiImportResult(
      importedCount: count,
      mode: mode,
      galleryRemoveFailedCount: galleryFailed,
    );
  }

  Future<_ImportOneResult> _importOneAsset({
    required AssetEntity asset,
    required String albumPath,
    required bool move,
  }) async {
    final fileName = await _resolveFileName(asset);
    final dest = await _uniqueDestPath(albumPath, fileName);

    final written = await _writeAssetToDest(asset, dest);
    if (!written || !await _destValid(dest)) {
      try {
        final partial = File(dest);
        if (await partial.exists()) await partial.delete();
      } catch (_) {}
      throw EmojiImportException('写入表情包夹失败');
    }

    if (move) {
      try {
        await _removeFromGallery(asset);
      } catch (_) {
        return const _ImportOneResult(
          written: true,
          galleryRemoveFailed: true,
        );
      }
    }

    return const _ImportOneResult(written: true);
  }

  Future<bool> _writeAssetToDest(AssetEntity asset, String dest) async {
    final src = await asset.originFile ??
        await asset.file ??
        await asset.loadFile(isOrigin: true);
    if (src != null && await src.exists()) {
      try {
        await src.copy(dest);
        if (await _destValid(dest)) return true;
      } catch (_) {}
    }

    final bytes = await _readAssetBytes(asset);
    if (bytes == null || bytes.isEmpty) return false;

    final out = File(dest);
    await out.writeAsBytes(bytes, flush: true);
    try {
      await out.setLastModified(asset.createDateTime);
    } catch (_) {}

    return await _destValid(dest);
  }

  Future<bool> _destValid(String dest) async {
    final file = File(dest);
    return await file.exists() && await file.length() > 0;
  }

  Future<void> _removeFromGallery(AssetEntity asset) async {
    final deleted = await PhotoManager.editor.deleteWithIds([asset.id]);
    if (deleted.isEmpty) {
      throw EmojiImportException('无法从相册移除');
    }
  }

  Future<Uint8List?> _readAssetBytes(AssetEntity asset) async {
    final origin = await asset.originFile;
    if (origin != null && await origin.exists()) {
      return origin.readAsBytes();
    }

    final compressed = await asset.file;
    if (compressed != null && await compressed.exists()) {
      return compressed.readAsBytes();
    }

    final loaded = await asset.loadFile(isOrigin: true);
    if (loaded != null && await loaded.exists()) {
      return loaded.readAsBytes();
    }

    return asset.originBytes;
  }

  Future<String> _resolveFileName(AssetEntity asset) async {
    final title = await asset.titleAsync;
    if (title.trim().isNotEmpty) {
      final t = title.trim();
      if (p.extension(t).isNotEmpty) return t;
      final mime = await asset.mimeTypeAsync ?? 'image/jpeg';
      final ext = mime.contains('png')
          ? '.png'
          : mime.contains('gif')
              ? '.gif'
              : mime.contains('webp')
                  ? '.webp'
                  : '.jpg';
      return '$t$ext';
    }
    return 'img_${asset.id}.jpg';
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

class EmojiImportException implements Exception {
  EmojiImportException(this.message);
  final String message;

  @override
  String toString() => message;
}
