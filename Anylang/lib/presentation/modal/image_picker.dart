import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Kamera/galereyadan rasm tanlash — pastdan chiqadigan tanlov sheet'i.
/// Loyihada rasm tanlash HAR DOIM shu funksiya orqali bajariladi
/// (`ImagePicker()` to'g'ridan-to'g'ri ishlatilmaydi).
/// [source] berilsa (masalan attach menyudan), qayta sheet ochilmaydi.
Future<File?> pickImage(BuildContext context, {ImageSource? source}) async {
  final resolved = source ??
      await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const _ImageSourceSheet(),
      );
  if (resolved == null) return null;

  final picked =
      await ImagePicker().pickImage(source: resolved, imageQuality: 85);
  if (picked == null) return null;
  return File(picked.path);
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 24.dp),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44.dp,
              height: 5.dp,
              decoration: BoxDecoration(color: c.outline, borderRadius: BorderRadius.circular(5.dp)),
            ),
            SizedBox(height: 16.dp),
            Text(
              'img_picker_title'.tr,
              style: TextStyle(color: c.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12.dp),
            _option(context, c, Icons.photo_camera_outlined, 'img_picker_camera'.tr, ImageSource.camera),
            _option(context, c, Icons.photo_library_outlined, 'img_picker_gallery'.tr, ImageSource.gallery),
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context, AppColors c, IconData icon, String label, ImageSource source) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, source),
        borderRadius: BorderRadius.circular(12.dp),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14.dp, horizontal: 8.dp),
          child: Row(
            children: [
              Icon(icon, color: c.textSecondary, size: 22.dp),
              SizedBox(width: 14.dp),
              Text(label, style: TextStyle(color: c.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
