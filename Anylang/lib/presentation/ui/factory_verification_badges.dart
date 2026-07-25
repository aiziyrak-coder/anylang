import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../modal/full_screen_image_dialog.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';
import 'factory_verification.dart';
import 'theme/colors.dart';

/// Factory Verified badge qatori: Factory Verified, Inspection, ISO, CE, FDA, Audit.
class FactoryVerificationBadges extends StatelessWidget {
  final FactoryVerification data;
  final bool compact;

  const FactoryVerificationBadges({
    super.key,
    required this.data,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!data.hasAny) return const SizedBox.shrink();
    final c = context.appColors;
    final chips = <Widget>[
      if (data.factoryVerified)
        _chip(
          c,
          label: 'factory_verified'.tr,
          icon: Icons.verified_rounded,
          highlight: true,
        ),
      if (data.inspectionPassed)
        _chip(c, label: 'factory_inspection_passed'.tr, icon: Icons.fact_check_outlined),
      if (data.iso) _chip(c, label: 'factory_badge_iso'.tr, icon: Icons.workspace_premium_outlined),
      if (data.ce) _chip(c, label: 'factory_badge_ce'.tr, icon: Icons.shield_outlined),
      if (data.fda) _chip(c, label: 'factory_badge_fda'.tr, icon: Icons.health_and_safety_outlined),
      if (data.hasAuditReport)
        _chip(
          c,
          label: 'factory_audit_report'.tr,
          icon: Icons.description_outlined,
          onTap: () => _openAudit(context, data.auditReportUrl!),
        ),
    ];
    return Wrap(
      spacing: compact ? 6.dp : 8.dp,
      runSpacing: compact ? 6.dp : 8.dp,
      children: chips,
    );
  }

  Widget _chip(
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
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8.dp : 10.dp,
        vertical: compact ? 5.dp : 7.dp,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99.dp),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14.dp : 16.dp, color: highlight ? c.accent : c.accent),
          SizedBox(width: 5.dp),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 11.sp : 12.sp,
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
