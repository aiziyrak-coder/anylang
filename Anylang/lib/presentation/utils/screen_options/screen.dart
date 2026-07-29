import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:anylang/presentation/utils/app_snackbar.dart';
import 'package:anylang/presentation/utils/screen_options/my_action.dart';
import 'package:anylang/presentation/utils/screen_options/screen_content.dart';
import 'package:anylang/presentation/utils/screen_options/screen_widget.dart';

abstract class Screen<S extends GetxController, Payload> {
  late final S state;
  final ScreenContent mobileContent;
  final ScreenContent? tabletContent;
  late BuildContext context;
  Payload? payload;

  /// Bir screen'dan bir vaqtda bitta push — ikki marta bosish stack'ni
  /// ikki marta ochib yubormasin.
  bool _navigationInFlight = false;

  /// Boshqa joyda ham (FAB) ikki marta bosishni oldini olish uchun.
  bool get isNavigating => _navigationInFlight;

  Screen({
    required this.mobileContent,
    this.tabletContent,
    this.payload,
    S Function()? createState,
  }) {
    state = createState != null ? createState() : Get.find<S>();
  }

  void initState(Payload? payload) {}

  void dispose() {}

  void uiBuildFinished() {}

  Future<void> sendAction(MyAction action) async {
    try {
      await actionHandler(state, action);
    } catch (e, st) {
      debugPrint('sendAction error: $e\n$st');
      showAppError(e.toString());
    }
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
    // Sync guard — await dan oldin, parallel tap stack'ni ko'paytirmasin.
    if (_navigationInFlight) return;
    _navigationInFlight = true;
    try {
      screen.payload = payload;

      final result = await Navigator.push<R>(
        context,
        MaterialPageRoute(
          builder: (context) => screen.build(),
        ),
      );

      onBackResult?.call(result);
    } finally {
      _navigationInFlight = false;
    }
  }

  void navigateAndRemoveUntil(Screen screen, {Object? payload}) {
    if (_navigationInFlight) return;
    _navigationInFlight = true;
    try {
      screen.payload = payload;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => screen.build()),
            (route) => false,
      );
    } finally {
      // pushAndRemoveUntil darhol tugaydi (await yo‘q) — lockni ochamiz.
      _navigationInFlight = false;
    }
  }

  void popBackNavigate() {
    Navigator.pop(context);
  }

  void popBackNavigateWithResult<R>(R result) {
    Navigator.pop(context, result);
  }
}
