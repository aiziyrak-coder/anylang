import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Til tanlash ro'yxatining bitta elementi (bayroq + nom + tanlangan belgisi).
class LanguageItem extends StatelessWidget {
  final String flagAsset;
  final String nativeName;
  final String localizedName;
  final bool selected;
  final VoidCallback onTap;

  const LanguageItem({
    super.key,
    required this.flagAsset,
    required this.nativeName,
    required this.localizedName,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16.dp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : c.surface,
            borderRadius: radius,
            border: Border.all(
              color: selected ? c.accent : c.surfaceBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 14.dp),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6.dp),
                child: Image.asset(
                  flagAsset,
                  width: 32.dp,
                  height: 24.dp,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: 14.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nativeName,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.dp),
                    Text(
                      localizedName,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  width: 24.dp,
                  height: 24.dp,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, color: c.onAccent, size: 16.dp),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
