import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/scam_risk.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

Future<void> showScamRiskBottomSheet(
  BuildContext context, {
  required ScamRisk risk,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ScamRiskSheet(risk: risk),
  );
}

class _ScamRiskSheet extends StatelessWidget {
  final ScamRisk risk;

  const _ScamRiskSheet({required this.risk});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final maxH = MediaQuery.sizeOf(context).height * 0.75;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.dp,
                  height: 4.dp,
                  decoration: BoxDecoration(
                    color: c.textFaint,
                    borderRadius: BorderRadius.circular(2.dp),
                  ),
                ),
              ),
              SizedBox(height: 16.dp),
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: c.danger, size: 22.dp),
                  SizedBox(width: 8.dp),
                  Expanded(
                    child: Text(
                      'scam_detection_title'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.dp),
              Text(
                risk.localizedMessage,
                style: TextStyle(
                  color: c.danger,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 8.dp),
              Text(
                'scam_detection_desc'.tr,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  height: 1.4,
                ),
              ),
              if (risk.reasons.isNotEmpty) ...[
                SizedBox(height: 16.dp),
                Text(
                  'scam_detection_reasons'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10.dp),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: risk.reasons.length,
                    separatorBuilder: (_, _) => SizedBox(height: 8.dp),
                    itemBuilder: (_, i) {
                      final r = risk.reasons[i];
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.dp,
                          vertical: 10.dp,
                        ),
                        decoration: BoxDecoration(
                          color: c.dangerSoft,
                          borderRadius: BorderRadius.circular(12.dp),
                          border: Border.all(color: c.danger.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: c.danger,
                              size: 18.dp,
                            ),
                            SizedBox(width: 10.dp),
                            Expanded(
                              child: Text(
                                r.localizedLabel,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Profil / mahsulotdagi AI Scam Detection banner.
class ScamRiskBanner extends StatelessWidget {
  final ScamRisk risk;
  final VoidCallback? onTap;

  const ScamRiskBanner({
    super.key,
    required this.risk,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!risk.hasWarning) return const SizedBox.shrink();
    final c = context.appColors;

    return Material(
      color: c.dangerSoft,
      borderRadius: BorderRadius.circular(14.dp),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.dp),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.dp),
            border: Border.all(color: c.danger.withValues(alpha: 0.35)),
          ),
          padding: EdgeInsets.all(12.dp),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                risk.isHigh
                    ? Icons.gpp_bad_rounded
                    : Icons.warning_amber_rounded,
                color: c.danger,
                size: 22.dp,
              ),
              SizedBox(width: 10.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'scam_detection_ai_label'.tr,
                      style: TextStyle(
                        color: c.danger,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 4.dp),
                    Text(
                      risk.localizedMessage,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    if (risk.reasons.isNotEmpty) ...[
                      SizedBox(height: 6.dp),
                      Text(
                        risk.reasons
                            .map((e) => e.localizedLabel)
                            .take(3)
                            .join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.sp,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: c.danger, size: 20.dp),
            ],
          ),
        ),
      ),
    );
  }
}
