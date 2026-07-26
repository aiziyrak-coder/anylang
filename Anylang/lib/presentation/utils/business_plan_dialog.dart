import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Business tarif kerak dialogi (mahsulot qo'shish / listing).
/// `true` — tariflar ekraniga o'tishni xohlaydi.
Future<bool> showBusinessPlanRequiredDialog() async {
  final goPlans = await Get.dialog<bool>(
    AlertDialog(
      title: Text('add_product_plan_required_title'.tr),
      content: Text('add_product_plan_required_body'.tr),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: Text('common_cancel'.tr),
        ),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: Text('add_product_go_plans'.tr),
        ),
      ],
    ),
  );
  return goPlans == true;
}
