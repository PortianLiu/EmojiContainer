import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/windows_tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (WindowsTrayService.supported) {
    await WindowsTrayService.instance.init();
    await WindowsTrayService.instance.setupContextMenu();
    await windowManager.setPreventClose(true);
  }

  runApp(const EmojiContainerApp());
}
