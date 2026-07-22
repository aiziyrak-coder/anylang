import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// Ro'yxat / qidiruv fetch paytidagi markaziy loading.
class AppLoading extends StatelessWidget {
  final String? message;

  const AppLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28.dp,
            height: 28.dp,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: c.accentText,
            ),
          ),
          SizedBox(height: 14.dp),
          Text(
            message ?? 'loading'.tr,
            style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }
}
