import 'package:flutter/material.dart';

/// Klaviatura ochilganda kontentni scroll qiladigan umumiy wrapper.
///
/// `ScreenWidget`da `resizeToAvoidBottomInset: false` — shuning uchun auth
/// va form ekranlari klaviatura balandligini shu widget orqali hisoblaydi.
/// Fokusdagi maydonni ko'rinadigan joyga surish `AppTextField` ichida
/// `Scrollable.ensureVisible` bilan qilinadi.
class KeyboardAwareScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool reverse;

  const KeyboardAwareScrollView({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.physics,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final resolved = padding.resolve(Directionality.of(context));

    return SingleChildScrollView(
      controller: controller,
      physics: physics,
      reverse: reverse,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: resolved.copyWith(bottom: resolved.bottom + keyboard),
      child: child,
    );
  }
}
