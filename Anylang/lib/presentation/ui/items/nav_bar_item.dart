import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Pastki navigatsiya barining yon elementi (ikon + yorliq + tanlangan holat).
class NavBarItem extends StatelessWidget {
  final String iconAsset;
  final String label;
  final bool selected;
  final int? badgeCount;
  final VoidCallback onTap;

  const NavBarItem({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.selected,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = selected ? c.accentText : c.textFaint;
    final iconColor = selected ? c.accent : c.textFaint;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16.dp),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.dp, horizontal: 2.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 42.dp,
                height: 30.dp,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.dp),
                  border: selected
                      ? Border.all(
                          color: c.accent.withValues(alpha: 0.35),
                          width: 0.8,
                        )
                      : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: SvgPicture.asset(
                        iconAsset,
                        width: 22.dp,
                        height: 22.dp,
                        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                      ),
                    ),
                    if (badgeCount != null && badgeCount! > 0)
                      Positioned(
                        top: -2.dp,
                        right: 0,
                        child: Container(
                          constraints: BoxConstraints(minWidth: 15.dp),
                          padding: EdgeInsets.symmetric(horizontal: 3.5.dp),
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.circular(8.dp),
                            boxShadow: [
                              BoxShadow(
                                color: c.accent.withValues(alpha: 0.45),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            badgeCount! > 99 ? '99+' : '$badgeCount',
                            style: TextStyle(
                              color: c.onAccent,
                              fontSize: 8.5.sp,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 3.dp),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  color: color,
                  fontSize: selected ? 10.sp : 9.5.sp,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  height: 1.1,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, maxLines: 1),
                ),
              ),
              SizedBox(height: 2.dp),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 12.dp : 0,
                height: 2.5.dp,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(2.dp),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: c.accent.withValues(alpha: 0.55),
                            blurRadius: 5,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
