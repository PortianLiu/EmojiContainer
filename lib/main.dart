import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/startup_timing_store.dart';
import 'services/windows_tray_service.dart';

Future<void> main() async {
  final sw = StageStopwatch();
  WidgetsFlutterBinding.ensureInitialized();

  // 每次启动清空上轮遗留（含旧版 prefs 持久化）
  await startupTimingStore.resetForNewSession();

  if (WindowsTrayService.supported) {
    await WindowsTrayService.instance.init();
    await WindowsTrayService.instance.setupContextMenu();
    await windowManager.setPreventClose(true);
    sw.lap('tray');
  }

  sw.setTotal();
  startupTimingStore.add(
    StartupTimingRecord(
      at: DateTime.now(),
      kind: 'main',
      stagesMs: Map<String, int>.from(sw.stagesMs),
      note: WindowsTrayService.supported ? 'windows' : 'mobile',
    ),
  );

  runApp(const EmojiContainerApp());
}
