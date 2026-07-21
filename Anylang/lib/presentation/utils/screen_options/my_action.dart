import 'package:flutter/material.dart';

abstract class MyAction {}

class Back extends MyAction {}
class Continue extends MyAction {}

/// Tema (Tungi/Kunduzgi/Avto) almashtirish — select_language va settings
/// ekranlarida ishlatiladi.
class ChangeThemeMode extends MyAction {
  final ThemeMode mode;
  ChangeThemeMode(this.mode);
}
