import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Windows：最小化到托盘，双击托盘恢复窗口
class WindowsTrayService with TrayListener, WindowListener {
  WindowsTrayService._();
  static final WindowsTrayService instance = WindowsTrayService._();

  bool _initialized = false;
  DateTime? _lastTrayClick;

  static bool get supported => Platform.isWindows;

  Future<void> init() async {
    if (!supported || _initialized) return;

    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1280, 720),
      center: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    trayManager.addListener(this);
    windowManager.addListener(this);

    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('表情包管理器');

    _initialized = true;
  }

  Future<void> hideToTray() async {
    if (!supported) return;
    await windowManager.hide();
  }

  Future<void> showFromTray() async {
    if (!supported) return;
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() {
    final now = DateTime.now();
    if (_lastTrayClick != null &&
        now.difference(_lastTrayClick!) <
            const Duration(milliseconds: 450)) {
      showFromTray();
      _lastTrayClick = null;
    } else {
      _lastTrayClick = now;
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      showFromTray();
    } else if (menuItem.key == 'quit') {
      trayManager.destroy();
      windowManager.destroy();
    }
  }

  @override
  void onWindowClose() async {
    await hideToTray();
  }

  Future<void> setupContextMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示主窗口'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '退出'),
        ],
      ),
    );
  }
}
