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
    final empty = a.views == 0 &&
        a.profileVisits == 0 &&
        a.listingClicks == 0 &&
        a.viewsSeries.every((v) => v == 0);

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
          child: empty
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.dp),
                  child: Text(
                    'profile_analytics_empty'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13.sp,
                      height: 1.35,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _metric(
                            c,
                            label: 'profile_analytics_views_7d'.tr,
                            value: '${a.views}',
                            delta: ProfileAnalytics7d.deltaPct(
                              a.views,
                              a.viewsPrev,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _metric(
                            c,
                            label: 'profile_analytics_visits'.tr,
                            value: '${a.profileVisits}',
                            delta: ProfileAnalytics7d.deltaPct(
                              a.profileVisits,
                              a.profileVisitsPrev,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _metric(
                            c,
                            label: 'profile_analytics_clicks'.tr,
                            value: '${a.listingClicks}',
                            delta: ProfileAnalytics7d.deltaPct(
                              a.listingClicks,
                              a.listingClicksPrev,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (a.conversionPct != null) ...[
                      SizedBox(height: 14.dp),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.dp,
                          vertical: 10.dp,
                        ),
                        decoration: BoxDecoration(
                          color: c.accentSoft,
                          borderRadius: BorderRadius.circular(12.dp),
                          border: Border.all(
                            color: c.accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swap_vert_rounded,
                              color: c.accent,
                              size: 18.dp,
                            ),
                            SizedBox(width: 8.dp),
                            Expanded(
                              child: Text(
                                'profile_analytics_conversion'.trParams({
                                  'n': a.conversionPct!
                                      .toStringAsFixed(
                                        a.conversionPct! ==
                                                a.conversionPct!.roundToDouble()
                                            ? 0
                                            : 1,
                                      ),
                                }),
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                    SizedBox(height: 8.dp),
                    _DayLabels(days: a.viewsSeriesDays, color: c.textFaint),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _metric(
    AppColors c, {
    required String label,
    required String value,
    int? delta,
  }) {
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
        if (delta != null) ...[
          SizedBox(height: 2.dp),
          Text(
            delta > 0
                ? '↑$delta%'
                : (delta < 0 ? '↓${delta.abs()}%' : '0%'),
            style: TextStyle(
              color: delta > 0
                  ? c.accent
                  : (delta < 0 ? c.danger : c.textFaint),
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

class _DayLabels extends StatelessWidget {
  final List<String> days;
  final Color color;

  const _DayLabels({required this.days, required this.color});

  @override
  Widget build(BuildContext context) {
    final labels = days.isEmpty
        ? List.generate(7, (_) => '')
        : days.map(_shortDay).toList();
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) SizedBox(width: 6.dp),
          Expanded(
            child: Text(
              labels[i],
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: color,
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _shortDay(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    const keys = [
      'profile_analytics_day_mon',
      'profile_analytics_day_tue',
      'profile_analytics_day_wed',
      'profile_analytics_day_thu',
      'profile_analytics_day_fri',
      'profile_analytics_day_sat',
      'profile_analytics_day_sun',
    ];
    return keys[dt.weekday - 1].tr;
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
