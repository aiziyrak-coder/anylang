import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../data/network/google_auth_service.dart';
import '../../utils/size_controller.dart';
import '../theme/colors.dart';
import 'rich_button.dart';

/// Login / Register — Google orqali kirish tugmasi (rasmiy G ikon).
class GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;
  final String? textKey;

  const GoogleSignInButton({
    super.key,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.textKey,
  });

  static bool get isConfigured =>
      kDebugMode || GoogleAuthService.serverClientId.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final googleOk = isConfigured;
    return RichButton(
      text: (textKey ?? 'google_sign_in').tr,
      isLoading: isLoading,
      enabled: enabled && googleOk,
      onTap: onTap,
      iconNearText: true,
      startIcon: SvgPicture.asset(
        'assets/icons/ic_google.svg',
        width: 20.dp,
        height: 20.dp,
      ),
      textColor: c.textSecondary,
      textStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
      padding: EdgeInsets.symmetric(vertical: 16.dp, horizontal: 16.dp),
      borderRadius: BorderRadius.all(Radius.circular(18.dp)),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
    );
  }
}
