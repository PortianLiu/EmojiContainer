import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/preferences_service.dart';
import '../../services/startup_timing_store.dart';
import '../../services/storage_permission_service.dart';
import 'root_directory_state.dart';

class RootDirectoryCubit extends Cubit<RootDirectoryState> {
  RootDirectoryCubit({
    required PreferencesService preferences,
    StoragePermissionService? storagePermission,
    StartupTimingStore? timingStore,
  })  : _preferences = preferences,
        _storage = storagePermission ?? StoragePermissionService(),
        _timing = timingStore ?? startupTimingStore,
        super(const RootDirectoryState());

  final PreferencesService _preferences;
  final StoragePermissionService _storage;
  final StartupTimingStore _timing;

  Future<void> loadSaved() async {
    final sw = StageStopwatch();
    emit(state.copyWith(status: RootDirectoryStatus.loading, clearError: true));
    final saved = await _preferences.getRootDirectory();
    sw.lap('prefs');
    if (saved == null || saved.isEmpty) {
      emit(const RootDirectoryState(status: RootDirectoryStatus.ready));
      sw.setTotal();
      _timing.add(
        StartupTimingRecord(
          at: DateTime.now(),
          kind: 'root',
          stagesMs: Map<String, int>.from(sw.stagesMs),
          note: 'no saved root',
        ),
      );
      return;
    }
    await _validateAndSet(saved, sw: sw);
  }

  Future<void> setPath(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          status: RootDirectoryStatus.error,
          errorMessage: '请输入有效的目录路径',
        ),
      );
      return;
    }
    emit(state.copyWith(status: RootDirectoryStatus.loading, clearError: true));
    await _validateAndSet(trimmed);
  }

  Future<void> clear() async {
    await _preferences.clearRootDirectory();
    emit(const RootDirectoryState(status: RootDirectoryStatus.ready));
  }

  Future<void> _validateAndSet(String path, {StageStopwatch? sw}) async {
    final timer = sw ?? StageStopwatch();
    final dir = Directory(path);
    if (!await dir.exists()) {
      emit(
        RootDirectoryState(
          status: RootDirectoryStatus.error,
          path: path,
          errorMessage: '目录不存在，请重新选择',
        ),
      );
      timer.lap('validate');
      timer.setTotal();
      _timing.add(
        StartupTimingRecord(
          at: DateTime.now(),
          kind: 'root',
          stagesMs: Map<String, int>.from(timer.stagesMs),
          note: 'dir missing',
        ),
      );
      return;
    }

    if (!await _storage.canReadDirectory(path)) {
      // 不把无权限路径当成已就绪，否则会立刻进主页并打断授权弹窗
      emit(
        RootDirectoryState(
          status: RootDirectoryStatus.error,
          errorMessage:
              '无法读取该目录。请先开启「允许访问所有文件」'
              '（不是相册/照片权限），再重新选择文件夹。',
        ),
      );
      timer.lap('validate');
      timer.setTotal();
      _timing.add(
        StartupTimingRecord(
          at: DateTime.now(),
          kind: 'root',
          stagesMs: Map<String, int>.from(timer.stagesMs),
          note: 'no read permission',
        ),
      );
      return;
    }

    try {
      await _preferences.setRootDirectory(path);
      emit(
        RootDirectoryState(
          status: RootDirectoryStatus.ready,
          path: path,
        ),
      );
      timer.lap('validate');
      timer.setTotal();
      _timing.add(
        StartupTimingRecord(
          at: DateTime.now(),
          kind: 'root',
          stagesMs: Map<String, int>.from(timer.stagesMs),
        ),
      );
    } catch (e) {
      emit(
        RootDirectoryState(
          status: RootDirectoryStatus.error,
          path: path,
          errorMessage: '无法保存目录设置：$e',
        ),
      );
      timer.lap('validate');
      timer.setTotal();
      _timing.add(
        StartupTimingRecord(
          at: DateTime.now(),
          kind: 'root',
          stagesMs: Map<String, int>.from(timer.stagesMs),
          note: 'save failed',
        ),
      );
    }
  }
}
