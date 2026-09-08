import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局单例：进程内各处写入，设置页读取（仅本会话，不跨启动持久化）
final startupTimingStore = StartupTimingStore();

/// 一次启动/刷新加载各阶段耗时（毫秒）
class StartupTimingRecord {
  const StartupTimingRecord({
    required this.at,
    required this.kind,
    required this.stagesMs,
    this.fromCache = false,
    this.albumCount,
    this.note,
  });

  final DateTime at;
  /// root | albums | main
  final String kind;
  final Map<String, int> stagesMs;
  final bool fromCache;
  final int? albumCount;
  final String? note;

  int get totalMs =>
      stagesMs['total'] ?? stagesMs.values.fold<int>(0, (a, b) => a + b);

  String get kindLabel => switch (kind) {
        'root' => '根目录就绪',
        'albums' => '相册加载',
        'main' => '进程启动',
        _ => kind,
      };

  static const stageLabels = <String, String>{
    'tray': '托盘/窗口初始化',
    'prefs': '读取设置',
    'validate': '校验目录与权限',
    'cacheRead': '读列表缓存',
    'firstList': '至首屏列表可画',
    'scan': '扫描文件系统',
    'cacheSave': '写回缓存',
    'nomedia': '写入 .nomedia',
    'total': '合计',
  };
}

/// 本会话启动/加载耗时；每次进程启动清空，不写磁盘以免拖慢关键路径
class StartupTimingStore extends ChangeNotifier {
  StartupTimingStore({int maxRecords = 30}) : _maxRecords = maxRecords;

  static const _legacyPrefsKey = 'startup_timing_history_v1';
  final int _maxRecords;
  final List<StartupTimingRecord> _records = [];

  List<StartupTimingRecord> get records => List.unmodifiable(_records);

  /// 启动时调用：清内存，并删掉旧版跨启动持久化残留
  Future<void> resetForNewSession() async {
    _records.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyPrefsKey);
    } catch (_) {}
  }

  void add(StartupTimingRecord record) {
    _records.insert(0, record);
    while (_records.length > _maxRecords) {
      _records.removeLast();
    }
    _log(record);
    notifyListeners();
  }

  void clear() {
    _records.clear();
    notifyListeners();
  }

  void _log(StartupTimingRecord r) {
    final parts = r.stagesMs.entries
        .map((e) => '${e.key}=${e.value}ms')
        .join(' ');
    debugPrint(
      '[StartupTiming] ${r.kindLabel} cache=${r.fromCache} '
      'albums=${r.albumCount ?? '-'} $parts'
      '${r.note != null ? ' (${r.note})' : ''}',
    );
  }
}

/// 分段计时：仅 Stopwatch + 几次 map 写入，相对磁盘扫描可忽略
class StageStopwatch {
  StageStopwatch() : _sw = Stopwatch()..start();

  final Stopwatch _sw;
  final Map<String, int> stagesMs = {};
  int _mark = 0;

  int lap(String name) {
    final now = _sw.elapsedMilliseconds;
    final delta = now - _mark;
    _mark = now;
    stagesMs[name] = delta;
    return delta;
  }

  int elapsed() => _sw.elapsedMilliseconds;

  void setTotal([String name = 'total']) {
    stagesMs[name] = _sw.elapsedMilliseconds;
  }
}
