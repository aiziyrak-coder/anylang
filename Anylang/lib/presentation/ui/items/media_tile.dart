import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';
import 'pill_badge.dart';

enum _MediaTileKind { upload, image }

/// Rasm tanlash panellarida (Zavod rasmlari, Mahsulot rasmlari) ishlatiladigan
/// bitta kvadrat plitka. `MediaTile.upload` — chiziqli chegarali "Yuklash"
/// joy egallovchisi. `MediaTile.image` — tanlangan rasm (gradient
/// placeholder), ixtiyoriy olib tashlash tugmasi va ixtiyoriy belgi bilan.
class MediaTile extends StatelessWidget {
  final _MediaTileKind _kind;
  final String? uploadLabel;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final VoidCallback? onRemove;
  final String? badgeText;
  final double size;

  const MediaTile.upload({
    super.key,
    required this.uploadLabel,
    required this.onTap,
    this.size = 90,
  })  : _kind = _MediaTileKind.upload,
        gradient = null,
        onRemove = null,
        badgeText = null;

  const MediaTile.image({
    super.key,
    required this.gradient,
    this.onRemove,
    this.badgeText,
    this.size = 90,
  })  : _kind = _MediaTileKind.image,
        uploadLabel = null,
        onTap = null;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(14.dp);
    final s = size.dp;

    if (_kind == _MediaTileKind.upload) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: c.accent, width: 1.4, style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.file_upload_outlined, size: 22.dp, color: c.accent),
                SizedBox(height: 4.dp),
                Text(
                  uploadLabel ?? '',
                  style: TextStyle(color: c.accent, fontSize: 11.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: gradient, borderRadius: radius),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 6.dp,
              right: 6.dp,
              child: Material(
                color: kNavy.withValues(alpha: 0.6),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(4.dp),
                    child: Icon(Icons.close_rounded, size: 14.dp, color: kAvatarFg),
                  ),
                ),
              ),
            ),
          if (badgeText != null)
            Positioned(
              bottom: 6.dp,
              left: 6.dp,
              child: PillBadge(
                label: badgeText!,
                background: c.accent,
                foreground: c.onAccent,
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }
}
