import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../ui/business_card_links.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/size_controller.dart';
import 'profile_action.dart';
import 'profile_pressable.dart';

/// AnyLang raqami — digital vizitka kartasi (7 xonali ID + QR + nusxa/ulash).
class ProfileAnyLangIdCard extends StatelessWidget {
  final int userId;
  final String anylangId;
  final void Function(MyAction) sendAction;

  const ProfileAnyLangIdCard({
    super.key,
    required this.userId,
    required this.anylangId,
    required this.sendAction,
  });

  @override
  Widget build(BuildContext context) {
    final url = userId > 0
        ? BusinessCardLinks.urlFor(userId)
        : (anylangId.isNotEmpty ? anylangId : '');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.dp),
      decoration: BoxDecoration(
        gradient: profileIdCardGradient,
        borderRadius: BorderRadius.circular(20.dp),
        boxShadow: [
          BoxShadow(
            color: const Color(0x33175CD3),
            blurRadius: 18.dp,
            offset: Offset(0, 8.dp),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profile_anylang_card_title'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 10.dp),
          Row(
            children: [
              Expanded(
                child: Text(
                  anylangId.isEmpty ? '—' : anylangId,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(8.dp),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.dp),
                ),
                child: QrImageView(
                  data: url.isEmpty ? '—' : url,
                  size: 72.dp,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF071526),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF071526),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.dp),
          Row(
            children: [
              Expanded(
                child: _cardBtn(
                  icon: Icons.copy_rounded,
                  label: 'profile_copy'.tr,
                  onTap: () => sendAction(CopyAnyLangId()),
                ),
              ),
              SizedBox(width: 10.dp),
              Expanded(
                child: _cardBtn(
                  icon: Icons.ios_share_rounded,
                  label: 'profile_share'.tr,
                  onTap: () => sendAction(ShareProfile()),
                ),
              ),
              SizedBox(width: 10.dp),
              Expanded(
                child: _cardBtn(
                  icon: Icons.qr_code_2_rounded,
                  label: 'profile_qr'.tr,
                  onTap: () => sendAction(ShowBusinessCardQr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ProfilePressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.dp),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.dp),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12.dp),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18.dp),
            SizedBox(height: 4.dp),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
