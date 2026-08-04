import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/buttons/primary_button.dart';
import '../ui/theme/colors.dart';
import '../ui/trust_score.dart';
import '../utils/size_controller.dart';

Future<void> showTrustScoreBottomSheet(
  BuildContext context, {
  required TrustScore trust,
  bool showActions = true,
  void Function(String action)? onAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = ctx.appColors;
      final levelKey = 'trust_level_${trust.level}';
      final levelLabel = levelKey.tr;
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
          border: Border(top: BorderSide(color: c.surfaceBorder, width: 0.7)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.dp, 10.dp, 20.dp, 20.dp),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.dp,
                  height: 4.dp,
                  decoration: BoxDecoration(
                    color: c.outline,
                    borderRadius: BorderRadius.circular(99.dp),
                  ),
                ),
                SizedBox(height: 14.dp),
                Row(
                  children: [
                    _TrustDot(level: trust.level, size: 12),
                    SizedBox(width: 8.dp),
                    Expanded(
                      child: Text(
                        'trust_score_title'.trParams({'n': '${trust.score}'}),
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.dp,
                        vertical: 4.dp,
                      ),
                      decoration: BoxDecoration(
                        color: trustLevelColor(c, trust.level)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99.dp),
                        border: Border.all(
                          color: trustLevelColor(c, trust.level)
                              .withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        levelLabel == levelKey
                            ? trust.level
                            : levelLabel,
                        style: TextStyle(
                          color: trustLevelColor(c, trust.level),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.dp),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'trust_score_desc'.tr,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13.sp,
                      height: 1.35,
                    ),
                  ),
                ),
                if (trust.nextGain > 0) ...[
                  SizedBox(height: 8.dp),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'trust_score_next_gain'
                          .trParams({'n': '${trust.nextGain}'}),
                      style: TextStyle(
                        color: c.accentText,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 16.dp),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: trust.breakdown.length,
                    separatorBuilder: (_, _) => SizedBox(height: 10.dp),
                    itemBuilder: (_, i) {
                      final f = trust.breakdown[i];
                      return _FactorRow(
                        factor: f,
                        colors: c,
                        showActions: showActions,
                        onAction: onAction,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class TrustScoreBadge extends StatelessWidget {
  final TrustScore trust;
  final VoidCallback? onTap;

  const TrustScoreBadge({
    super.key,
    required this.trust,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = trustLevelColor(c, trust.level);
    final radius = BorderRadius.circular(99.dp);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 7.dp),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: radius,
            border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TrustDot(level: trust.level, size: 8),
              SizedBox(width: 6.dp),
              Text(
                'trust_score_badge'.trParams({'n': '${trust.score}'}),
                style: TextStyle(
                  color: color,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color trustLevelColor(AppColors c, String level) {
  switch (level) {
    case 'excellent':
      return kOnline;
    case 'good':
      return c.accentText;
    case 'fair':
      return kTrustFair;
    default:
      return kListenRed;
  }
}

class _TrustDot extends StatelessWidget {
  final String level;
  final double size;

  const _TrustDot({required this.level, required this.size});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: size.dp,
      height: size.dp,
      decoration: BoxDecoration(
        color: trustLevelColor(c, level),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  final TrustFactor factor;
  final AppColors colors;
  final bool showActions;
  final void Function(String action)? onAction;

  const _FactorRow({
    required this.factor,
    required this.colors,
    required this.showActions,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final pct =
        factor.max <= 0 ? 0.0 : (factor.score / factor.max).clamp(0.0, 1.0);
    final tipKey = 'trust_tip_${factor.key}';
    final tip = tipKey.tr;
    final ctaLabel = _ctaLabel(factor.action);
    final wantCta = showActions &&
        onAction != null &&
        factor.action != 'none' &&
        factor.action != 'keep_clean' &&
        !factor.complete;

    return Container(
      padding: EdgeInsets.all(12.dp),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(14.dp),
        border: Border.all(color: c.surfaceBorder, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'trust_factor_${factor.key}'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${factor.score}/${factor.max}',
                style: TextStyle(
                  color: c.accentText,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (_subtitle(factor).isNotEmpty) ...[
            SizedBox(height: 4.dp),
            Text(
              _subtitle(factor),
              style: TextStyle(color: c.textSecondary, fontSize: 11.sp),
            ),
          ],
          SizedBox(height: 8.dp),
          ClipRRect(
            borderRadius: BorderRadius.circular(99.dp),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6.dp,
              backgroundColor: c.surfaceBorder,
              color: c.accent,
            ),
          ),
          if (!factor.complete && tip != tipKey) ...[
            SizedBox(height: 8.dp),
            Text(
              tip,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.sp,
                height: 1.35,
              ),
            ),
          ],
          if (factor.action == 'keep_clean' &&
              showActions &&
              (factor.count ?? 0) > 0) ...[
            SizedBox(height: 8.dp),
            Text(
              tip != tipKey ? tip : 'trust_tip_complaints'.tr,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.sp,
                height: 1.35,
              ),
            ),
          ],
          if (wantCta && ctaLabel != null) ...[
            SizedBox(height: 10.dp),
            PrimaryButton(
              text: ctaLabel,
              onTap: () {
                Navigator.of(context).maybePop();
                onAction!(factor.action);
              },
            ),
          ],
        ],
      ),
    );
  }

  String? _ctaLabel(String action) {
    switch (action) {
      case 'add_certificates':
        return 'trust_cta_add_certs'.tr;
      case 'verify_documents':
        return 'trust_cta_verify'.tr;
      case 'reply_faster':
        return 'trust_cta_reply'.tr;
      case 'send_invoices':
        return 'trust_cta_invoices'.tr;
      default:
        return null;
    }
  }

  String _subtitle(TrustFactor f) {
    switch (f.key) {
      case 'certificates':
        return 'trust_factor_certificates_sub'.trParams({'n': '${f.count ?? 0}'});
      case 'response_speed':
        if (f.avgMinutes == null) return 'trust_factor_response_na'.tr;
        final m = f.avgMinutes!;
        if (m < 60) {
          return 'trust_factor_response_min'.trParams({'n': '${m.round()}'});
        }
        return 'trust_factor_response_hr'.trParams({
          'n': (m / 60).toStringAsFixed(1),
        });
      case 'complaints':
        return 'trust_factor_complaints_sub'.trParams({'n': '${f.count ?? 0}'});
      case 'successful_deals':
        return 'trust_factor_deals_sub'.trParams({'n': '${f.count ?? 0}'});
      case 'verified_documents':
        final ok = f.documentsVerified == true || f.verifiedBadge == true;
        return ok ? 'trust_factor_docs_ok'.tr : 'trust_factor_docs_pending'.tr;
      default:
        return '';
    }
  }
}
