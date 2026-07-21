import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/theme/theme_controller.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'jonli_action.dart';
import 'jonli_content.dart';
import 'jonli_state.dart';

class JonliScreen extends Screen<JonliState, void> {

  JonliScreen() : super(
    mobileContent: JonliContent(),
  );

  @override
  Future<void> actionHandler(JonliState state, MyAction action) async {
    switch (action) {
      case StartSpeaking a:
        state.mode.value = a.isMe ? JonliMode.me : JonliMode.other;
      case StopSpeaking _:
        state.mode.value = JonliMode.idle;
      case SwapLanguages _:
        final my = state.myLanguage.value;
        state.myLanguage.value = state.otherLanguage.value;
        state.otherLanguage.value = my;
      case ToggleTheme _:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        Get.find<ThemeController>().setMode(isDark ? ThemeMode.light : ThemeMode.dark);
      case SelectMyLanguage a:
        state.myLanguage.value = a.language;
      case SelectOtherLanguage a:
        state.otherLanguage.value = a.language;
    }
  }
}
