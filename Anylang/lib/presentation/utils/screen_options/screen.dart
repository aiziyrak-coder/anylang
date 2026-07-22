import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:anylang/presentation/utils/screen_options/my_action.dart';
import 'package:anylang/presentation/utils/screen_options/screen_content.dart';
import 'package:anylang/presentation/utils/screen_options/screen_widget.dart';

abstract class Screen<S extends GetxController, Payload> {
  late final S state;
  final ScreenContent mobileContent;
  final ScreenContent? tabletContent;
  late BuildContext context;
  Payload? payload;

  Screen({
    required this.mobileContent,
    this.tabletContent,
    this.payload
  }) {
    state = Get.find<S>();
  }

  void initState(Payload? payload) {}

  void dispose() {}

  void uiBuildFinished() {}

  void sendAction(MyAction action) {
    actionHandler(state, action);
  }

  Future<void> actionHandler(S state, MyAction action) async {}

  Widget build() {

    return ScreenWidget(
      mobileContent: mobileContent,
      tabletContent: tabletContent,
      state: state,
      initState: ()=> initState(payload),
      dispose: dispose,
      uiBuildFinished: uiBuildFinished,
      setContextCallback: (ctx) => context = ctx,
      sendActionCallback: sendAction,
    );
  }

  Future<void> navigate<R>(
      Screen screen, {
        Object? payload,
        void Function(R? result)? onBackResult,
      }) async {
    screen.payload = payload;

    final result = await Navigator.push<R>(
      context,
      MaterialPageRoute(
        builder: (context) => screen.build(),
      ),
    );

    onBackResult?.call(result);
  }

  void navigateAndRemoveUntil(Screen screen, {Object? payload}) {
    screen.payload = payload;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => screen.build()),
          (route) => false,
    );
  }

  void popBackNavigate() {
    Navigator.pop(context);
  }

  void popBackNavigateWithResult<R>(R result) {
    Navigator.pop(context, result);
  }
}
