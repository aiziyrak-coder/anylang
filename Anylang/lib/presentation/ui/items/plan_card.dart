import 'package:flutter/material.dart';
import '../buttons/secondary_button.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';
import 'pill_badge.dart';

/// Tarif kartasidagi bitta xususiyat qatori (belgi + matn). `included=false`
/// bo'lsa xira X bilan ko'rsatiladi (masalan Basic tarifdagi cheklov).
class PlanFeature {
  final String text;
  final bool included;

  const PlanFeature(this.text, {this.included = true});
}

/// Tariflar (S16) ekranidagi bitta tarif kartasi. Joriy tanlangan tarif
/// (`highlighted`) lime chegara bilan ajratiladi va burchakda `badgeText`
/// ko'rsatiladi (masalan "JORIY TARIF" yoki "SOTUVCHILAR").
class PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String? priceSuffix;
  final List<PlanFeature> features;
  final bool highlighted;
  final String? badgeText;
  final IconData? badgeIcon;
  final String ctaText;
  final VoidCallback? onCta;
  final bool ctaEnabled;
  /// Optional line under price (e.g. yearly billed total).
  final String? priceNote;

  const PlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.features,
    required this.ctaText,
    this.priceSuffix,
    this.highlighted = false,
    this.badgeText,
    this.badgeIcon,
    this.onCta,
    this.ctaEnabled = true,
    this.priceNote,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(18.dp);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(18.dp, 20.dp, 18.dp, 18.dp),
          decoration: BoxDecoration(
            color: highlighted ? c.accentSoft : c.surface,
            borderRadius: radius,
            border: Border.all(color: highlighted ? c.accent : c.outline, width: highlighted ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: highlighted ? c.accentText : c.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (badgeText != null && !highlighted) ...[
                    const Spacer(),
                    PillBadge(
                      label: badgeText!,
                      background: c.outline,
                      foreground: c.textSecondary,
                      fontSize: 10,
                    ),
                  ],
                ],
              ),
              SizedBox(height: 6.dp),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    price,
                    style: TextStyle(color: c.textPrimary, fontSize: 26.sp, fontWeight: FontWeight.w700),
                  ),
                  if (priceSuffix != null) ...[
                    SizedBox(width: 4.dp),
                    Text(
                      priceSuffix!,
                      style: TextStyle(color: c.textFaint, fontSize: 13.sp),
                    ),
                  ],
                ],
              ),
              if (priceNote != null && priceNote!.isNotEmpty) ...[
                SizedBox(height: 4.dp),
                Text(
                  priceNote!,
                  style: TextStyle(color: c.textFaint, fontSize: 12.sp),
                ),
              ],
              SizedBox(height: 14.dp),
              for (final f in features) _featureRow(c, f),
              SizedBox(height: 16.dp),
              SecondaryButton(
                text: ctaText,
                enabled: ctaEnabled,
                onTap: onCta ?? () {},
              ),
            ],
          ),
        ),
        if (badgeText != null && highlighted)
          Positioned(
            top: -12.dp,
            left: 16.dp,
            child: PillBadge(
              label: badgeText!,
              icon: badgeIcon,
              background: c.accent,
              foreground: c.onAccent,
              fontSize: 10,
            ),
          ),
      ],
    );
  }

  Widget _featureRow(AppColors c, PlanFeature f) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.dp),
      child: Row(
        children: [
          Icon(
            f.included ? Icons.check_rounded : Icons.close_rounded,
            size: 16.dp,
            color: f.included ? c.accent : c.textFaint,
          ),
          SizedBox(width: 8.dp),
          Expanded(
            child: Text(
              f.text,
              style: TextStyle(
                color: f.included ? c.textSecondary : c.textFaint,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
