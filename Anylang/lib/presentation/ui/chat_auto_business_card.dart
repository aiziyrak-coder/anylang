import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/local/countries_service.dart';
import '../../domain/models/country_option.dart';
import '../screens/chat/chat_message.dart';
import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// Noma'lum odam xabari tepasidagi avto biznes kartochka.
class ChatAutoBusinessCard extends StatelessWidget {
  final AutoBusinessCard card;
  final VoidCallback? onTap;

  const ChatAutoBusinessCard({
    super.key,
    required this.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final country = _countryLabel(card.country);
    final rating = card.rating;
    final radius = BorderRadius.circular(14.dp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(12.dp, 10.dp, 12.dp, 10.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: radius,
            border: Border.all(color: c.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'auto_biz_card_label'.tr,
                style: TextStyle(
                  color: c.textFaint,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 6.dp),
              _row('🏢', card.companyName.isEmpty ? '—' : card.companyName, c,
                  bold: true),
              if (country != null) ...[
                SizedBox(height: 4.dp),
                _row('🌍', country, c),
              ],
              SizedBox(height: 4.dp),
              _row(
                '✅',
                card.verified
                    ? 'auto_biz_card_verified'.tr
                    : 'auto_biz_card_unverified'.tr,
                c,
                accent: card.verified,
              ),
              SizedBox(height: 4.dp),
              _row(
                '⭐',
                rating != null
                    ? 'auto_biz_card_rating'.trParams({
                        'n': rating.toStringAsFixed(
                          rating == rating.roundToDouble() ? 0 : 1,
                        ),
                      })
                    : 'auto_biz_card_rating_na'.tr,
                c,
              ),
              SizedBox(height: 4.dp),
              _row(
                '📦',
                'auto_biz_card_products'.trParams({
                  'n': '${card.productsCount}',
                }),
                c,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    String emoji,
    String text,
    AppColors c, {
    bool bold = false,
    bool accent = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: TextStyle(fontSize: 13.sp)),
        SizedBox(width: 8.dp),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: accent ? c.accent : c.textPrimary,
              fontSize: 13.sp,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  String? _countryLabel(String? code) {
    final raw = (code ?? '').trim().toUpperCase();
    if (raw.isEmpty) return null;
    try {
      if (Get.isRegistered<CountriesService>()) {
        final svc = Get.find<CountriesService>();
        final match = svc.findByCode(raw);
        if (match != null) {
          final flag = match.flagEmoji.trim();
          final name = match.localizedName.trim();
          if (flag.isNotEmpty && name.isNotEmpty) return '$flag $name';
          if (name.isNotEmpty) return name;
        }
      }
      for (final o in kFallbackCountries) {
        if (o.code.toUpperCase() == raw) {
          final flag = o.flagEmoji.trim();
          final name = o.localizedName.trim();
          if (flag.isNotEmpty && name.isNotEmpty) return '$flag $name';
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {}
    return raw;
  }
}