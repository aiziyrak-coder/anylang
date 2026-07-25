import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../ui/business_card_links.dart';
import '../ui/buttons/primary_button.dart';
import '../ui/buttons/secondary_button.dart';
import '../ui/theme/colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';

/// Biznes kartochka QR — ko‘rgazmada skaner qilinadi.
Future<void> showBusinessCardQrBottomSheet(
  BuildContext context, {
  required int userId,
  required String companyName,
}) {
  final url = BusinessCardLinks.urlFor(userId);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BusinessCardQrSheet(
      url: url,
      companyName: companyName,
    ),
  );
}

class _BusinessCardQrSheet extends StatelessWidget {
  final String url;
  final String companyName;

  const _BusinessCardQrSheet({
    required this.url,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final maxH = MediaQuery.sizeOf(context).height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 20.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.dp,
                height: 4.dp,
                decoration: BoxDecoration(
                  color: c.textFaint,
                  borderRadius: BorderRadius.circular(2.dp),
                ),
              ),
              SizedBox(height: 16.dp),
              Text(
                'business_card_qr_title'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.dp),
              Text(
                'business_card_qr_desc'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 18.dp),
              Container(
                padding: EdgeInsets.all(16.dp),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(18.dp),
                  border: Border.all(color: c.outline),
                ),
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(8.dp),
                  child: QrImageView(
                    data: url,
                    version: QrVersions.auto,
                    size: 220.dp,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: kNavy,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: kNavy,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.dp),
              Text(
                companyName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.dp),
              SelectableText(
                url,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 18.dp),
              PrimaryButton(
                text: 'business_card_copy_link'.tr,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  showAppMessage('business_card_link_copied'.tr);
                },
              ),
              SizedBox(height: 10.dp),
              SecondaryButton(
                text: 'cancel'.tr,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
