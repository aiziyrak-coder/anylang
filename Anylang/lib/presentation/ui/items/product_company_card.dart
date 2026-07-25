import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Mahsulot ostidagi kompaniya kartasi:
/// 🏭 CDC Group · ⭐ 4.9 · ✅ Verified · 🌍 N davlatga eksport
class ProductCompanyCard extends StatelessWidget {
  final String companyName;
  final double? rating;
  final bool verified;
  final int exportCountriesCount;
  final String? logoUrl;
  final bool loading;
  final VoidCallback onTap;

  const ProductCompanyCard({
    super.key,
    required this.companyName,
    required this.onTap,
    this.rating,
    this.verified = false,
    this.exportCountriesCount = 0,
    this.logoUrl,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16.dp);
    final name = loading ? '…' : companyName;
    final logo = logoUrl?.trim();

    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: loading ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.outline),
          ),
          padding: EdgeInsets.fromLTRB(14.dp, 14.dp, 10.dp, 14.dp),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _logo(c, logo, name),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏭 $name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (!loading) ...[
                      if (rating != null) ...[
                        SizedBox(height: 8.dp),
                        _line(
                          c,
                          leading: '⭐',
                          text: rating!.toStringAsFixed(1),
                          emphasize: true,
                        ),
                      ],
                      if (verified) ...[
                        SizedBox(height: 6.dp),
                        _line(
                          c,
                          leading: '✅',
                          text: 'user_card_verified'.tr,
                          color: c.accent,
                        ),
                      ],
                      if (exportCountriesCount > 0) ...[
                        SizedBox(height: 6.dp),
                        _line(
                          c,
                          leading: '🌍',
                          text: 'product_company_exports'.trParams({
                            'n': '$exportCountriesCount',
                          }),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 2.dp),
                child: Icon(Icons.chevron_right_rounded, color: c.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo(AppColors c, String? logo, String name) {
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
    return Container(
      width: 48.dp,
      height: 48.dp,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(14.dp),
        border: Border.all(color: c.outline),
        image: logo != null && logo.isNotEmpty
            ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover)
            : null,
      ),
      child: logo == null || logo.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: c.accent,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  Widget _line(
    AppColors c, {
    required String leading,
    required String text,
    Color? color,
    bool emphasize = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(leading, style: TextStyle(fontSize: 13.sp)),
        SizedBox(width: 6.dp),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color ?? c.textSecondary,
              fontSize: 13.sp,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
