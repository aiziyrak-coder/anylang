import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/theme/colors.dart';
import '../../utils/size_controller.dart';
import 'profile_insights.dart';

/// Oxirgi 7 kun: ko‘rishlar, tashriflar, e’lon bosishlar + mini grafik.
class ProfileAnalyticsSection extends StatelessWidget {
  final ProfileInsights insights;

  const ProfileAnalyticsSection({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final a = insights.analytics7d;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'profile_analytics_title'.tr.toUpperCase(),
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 10.dp),
        Container(
          padding: EdgeInsets.all(14.dp),
          decoration: BoxDecoration(
            color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
            borderRadius: BorderRadius.circular(18.dp),
            border: Border.all(color: c.surfaceBorder, width: 0.7),
            boxShadow: c.glassShadow,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      c,
                      label: 'profile_analytics_views_7d'.tr,
                      value: '${a.views}',
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      c,
                      label: 'profile_analytics_visits'.tr,
                      value: '${a.profileVisits}',
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      c,
                      label: 'profile_analytics_clicks'.tr,
                      value: '${a.listingClicks}',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.dp),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'profile_analytics_chart'.tr,
                  style: TextStyle(
                    color: c.textFaint,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 10.dp),
              SizedBox(
                height: 72.dp,
                child: _MiniBarChart(
                  values: a.viewsSeries.isEmpty
                      ? List<int>.filled(7, 0)
                      : a.viewsSeries,
                  color: c.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(AppColors c, {required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4.dp),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: c.textFaint,
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<int> values;
  final Color color;

  const _MiniBarChart({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<int>(0, (m, v) => v > m ? v : m);
    final denom = maxV <= 0 ? 1 : maxV;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) SizedBox(width: 6.dp),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: values[i] / denom),
              duration: Duration(milliseconds: 400 + i * 40),
              curve: Curves.easeOutCubic,
              builder: (_, t, _) {
                return FractionallySizedBox(
                  heightFactor: (0.12 + t * 0.88).clamp(0.12, 1.0),
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.35 + t * 0.55),
                      borderRadius: BorderRadius.circular(6.dp),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
