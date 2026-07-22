import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Davlat/til tanlash ro'yxati elementi — bayroq emoji + nom + kod + check.
class CountryListItem extends StatelessWidget {
  final String flagEmoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const CountryListItem({
    super.key,
    required this.flagEmoji,
    required this.title,
    required this.subtitle,
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
              Container(
                width: 40.dp,
                height: 40.dp,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(10.dp),
                ),
                child: Text(
                  flagEmoji.isEmpty ? '🏳️' : flagEmoji,
                  style: TextStyle(fontSize: 22.sp),
                ),
              ),
              SizedBox(width: 14.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.dp),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
