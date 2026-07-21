import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

/// Ilova temasi (light / dark / system) — Hive'da saqlanadi va GetX orqali
/// almashtiriladi. Select Language ekranidagi Kunduzgi/Tungi/Tizim tugmalari
/// shu controller orqali ishlaydi.
class ThemeController extends GetxController {
  static const _boxName = 'user';
  static const _key = 'themeMode';

  final Rx<ThemeMode> mode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    mode.value = _read();
  }

  ThemeMode _read() {
    final box = Hive.box(_boxName);
    switch (box.get(_key, defaultValue: 'system')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setMode(ThemeMode value) {
    mode.value = value;
    Get.changeThemeMode(value);
    Hive.box(_boxName).put(_key, value.name);
  }
}
