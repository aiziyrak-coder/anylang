import 'package:flutter/material.dart';

import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// Bo'sh ro'yxat / qidiruv natijasi yo'q holati.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final showAction =
        actionLabel != null &&
        actionLabel!.trim().isNotEmpty &&
        onAction != null;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40.dp, color: c.textFaint),
            SizedBox(height: 14.dp),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              SizedBox(height: 6.dp),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
              ),
            ],
            if (showAction) ...[
              SizedBox(height: 16.dp),
              Material(
                color: c.accent,
                borderRadius: BorderRadius.circular(14.dp),
                child: InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(14.dp),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.dp,
                      vertical: 12.dp,
                    ),
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        color: c.onAccent,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
