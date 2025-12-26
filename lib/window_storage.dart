import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WindowStorage with WindowListener {
  static const _keyWidth = 'window_width';
  static const _keyHeight = 'window_height';

  static Future<void> initialize({
    required String title,
    Size defaultSize = const Size(800, 500),
    Size minSize = const Size(400, 400),
    Offset defaultPosition = const Offset(100, 100),
  }) async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    final prefs = await SharedPreferences.getInstance();

    final double swidth = prefs.getDouble(_keyWidth) ?? defaultSize.width;
    final double sheight = prefs.getDouble(_keyHeight) ?? defaultSize.height;

    final double width = (swidth == 0.0 || swidth > 2000.0) ? 800.0 : swidth;
    final double height = (sheight == 0.0 || sheight > 2000.0)
        ? 500.0
        : sheight;

    await windowManager.ensureInitialized();

    final options = WindowOptions(
      size: Size(width, height),
      center: true,
      minimumSize: minSize,
      title: title,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    windowManager.addListener(MyWindowListener());
  }
}

class MyWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    final size = await windowManager.getSize();
    final prefs = await SharedPreferences.getInstance();

    double width = (size.width == 0.0 || size.width > 2000.0)
        ? 800.0
        : size.width;
    double height = (size.height == 0.0 || size.height > 2000.0)
        ? 500.0
        : size.height;

    await prefs.setDouble("window_width", width);
    await prefs.setDouble("window_height", height);
  }
}
