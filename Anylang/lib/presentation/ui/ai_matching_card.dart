import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/size_controller.dart';
import 'ai_matching.dart';
import 'theme/colors.dart';

/// Profil / Bozor uchun AI Matching preview kartasi.
class AiMatchingCard extends StatelessWidget {
  final AiMatchingResult? result;
  final bool loading;
  final bool loadFailed;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const AiMatchingCard({
    super.key,
    this.result,
    this.loading = false,
    this.loadFailed = false,
    this.onTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final top = result?.items.isNotEmpty == true ? result!.items.first : null;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(18.dp),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.dp),
        onTap: loading ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.dp),
            border: Border.all(color: c.outline),
          ),
          padding: EdgeInsets.all(14.dp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36.dp,
                    height: 36.dp,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(12.dp),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, color: c.accent, size: 20.dp),
                  ),
                  SizedBox(width: 10.dp),
                  Expanded(
                    child: Text(
                      'ai_matching_title'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (loading)
                    SizedBox(
                      width: 18.dp,
                      height: 18.dp,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.accent,
                      ),
                    )
                  else
                    Icon(Icons.chevron_right_rounded, color: c.textFaint),
                ],
              ),
              SizedBox(height: 12.dp),
              if (loading)
                Text(
                  'ai_matching_loading'.tr,
                  style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
                )
              else if (loadFailed)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ai_matching_load_failed'.tr,
                        style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
                      ),
                    ),
                    if (onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        child: Text('common_retry'.tr),
                      ),
                  ],
                )
              else if (top == null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ai_matching_empty'.tr,
                        style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
                      ),
                    ),
                    if (onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        child: Text('common_retry'.tr),
                      ),
                  ],
                )
              else
                Text(
                  top.message,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              if (!loading && result != null && result!.items.length > 1) ...[
                SizedBox(height: 8.dp),
                Text(
                  'ai_matching_more'.trParams({'n': '${result!.items.length - 1}'}),
                  style: TextStyle(color: c.accent, fontSize: 12.sp, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
