import 'dart:async';

import 'package:flutter/material.dart';
import 'package:anylang/presentation/utils/screen_options/my_action.dart';

abstract class ScreenContent<S> {

  final Color? color;

  bool isKeyboardOpen = false;

  ScreenContent({this.color});

  Widget build(
    BuildContext context,
    S state,
    FutureOr<void> Function(MyAction) sendAction,
  );

  void initContent() {}
  void uiBuildFinished(S state) {}
  void onClose() {}
}
