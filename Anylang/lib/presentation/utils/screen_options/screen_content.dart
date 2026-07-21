import 'package:flutter/material.dart';
import 'package:anylang/presentation/ui/theme/colors.dart';
import 'package:anylang/presentation/utils/screen_options/my_action.dart';

abstract class ScreenContent<S> {

  final Color color;

  bool isKeyboardOpen = false;

  ScreenContent({this.color = mainBackground});

  Widget build(BuildContext context, S state, void Function(MyAction) sendAction);

  void initContent() {}
  void uiBuildFinished(S state) {}
  void onClose() {}
}
