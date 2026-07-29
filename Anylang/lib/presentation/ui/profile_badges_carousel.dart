import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../modal/full_screen_image_dialog.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';
import 'auto_scroll_chip_carousel.dart';
import 'factory_verification.dart';
import 'theme/colors.dart';

/// Profil badge’lari: networking + ishonch + factory — bitta aylanadigan qator.
class ProfileBadgesCarousel extends StatelessWidget {
  final int connections;
  final int countries;
  final int? trust;
  final bool showTrustedMark;
  final bool showVerifiedPill;
  final FactoryVerification factoryVerification;

  const ProfileBadgesCarousel({
    super.key,
    this.connections = 0,
    this.countries = 0,
    this.trust,
    this.showTrustedMark = false,
    this.showVerifiedPill = false,
    this.factoryVerification = const FactoryVerification(),
  });

  bool get hasAny =>
      connections > 0 ||
      countries > 0 ||
      trust != null ||
      showTrustedMark ||
      showVerifiedPill ||
      factoryVerification.hasAny;

  @override
  Widget build(BuildContext context) {
    if (!hasAny) return const SizedBox.shrink();
    final c = context.appColors;
    final chips = <Widget>[
      if (connections > 0)
        _emojiChip(
          c,
          '🤝',
          'networking_connections'.trParams({'n': _fmt(connections)}),
        ),
      if (countries > 0)
        _emojiChip(
          c,
          '🌍',
          'networking_countries'.trParams({'n': _fmt(countries)}),
        ),
      if (trust != null)
        _emojiChip(
          c,
          '⭐',
          'networking_trust'.trParams({'n': '${trust!.clamp(0, 100)}'}),
        ),
      if (showTrustedMark)
        _iconChip(
          c,
          label: 'verification_trusted_mark'.tr,
          icon: Icons.verified_rounded,
          highlight: true,
        ),
      if (showVerifiedPill)
        _iconChip(
          c,
          label: 'profile_verified'.tr,
          icon: Icons.verified_rounded,
          highlight: true,
        ),
      if (factoryVerification.factoryVerified)
        _iconChip(
          c,
          label: 'factory_verified'.tr,
          icon: Icons.verified_rounded,
          highlight: true,
        ),
      if (factoryVerification.inspectionPassed)
        _iconChip(
          c,
          label: 'factory_inspection_passed'.tr,
          icon: Icons.fact_check_outlined,
        ),
      if (factoryVerification.iso)
        _iconChip(
          c,
          label: 'factory_badge_iso'.tr,
          icon: Icons.workspace_premium_outlined,
        ),
      if (factoryVerification.ce)
        _iconChip(
          c,
          label: 'factory_badge_ce'.tr,
          icon: Icons.shield_outlined,
        ),
      if (factoryVerification.fda)
        _iconChip(
          c,
          label: 'factory_badge_fda'.tr,
          icon: Icons.health_and_safety_outlined,
        ),
      if (factoryVerification.hasAuditReport)
        _iconChip(
          c,
          label: 'factory_audit_report'.tr,
          icon: Icons.description_outlined,
          onTap: () => _openAudit(context, factoryVerification.auditReportUrl!),
        ),
    ];

    return AutoScrollChipCarousel(children: chips);
  }

  String _fmt(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      final s = k == k.roundToDouble() ? '${k.toInt()}' : k.toStringAsFixed(1);
      return '${s}k';
    }
    return '$n';
  }

  Widget _emojiChip(AppColors c, String emoji, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 8.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(99.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 13.sp)),
          SizedBox(width: 6.dp),
          Text(
            label,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconChip(
    AppColors c, {
    required String label,
    required IconData icon,
    bool highlight = false,
    VoidCallback? onTap,
  }) {
    final bg = highlight ? c.accentSoft : c.surface;
    final fg = highlight ? c.accentText : c.textPrimary;
    final border = highlight ? c.accent : c.outline;
    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 7.dp),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99.dp),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.dp, color: c.accent),
          SizedBox(width: 5.dp),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99.dp),
        onTap: onTap,
        child: child,
      ),
    );
  }

  Future<void> _openAudit(BuildContext context, String url) async {
    final lower = url.toLowerCase();
    final looksImage = lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.contains('/audit/');
    if (looksImage) {
      await showFullScreenImage(context, url: url);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showAppError('factory_audit_open_failed'.tr);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) showAppError('factory_audit_open_failed'.tr);
  }
}
