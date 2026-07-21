import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Pastki navigatsiya barining bitta elementi (ikon + yorliq + tanlangan holat).
/// Tanlanganda `textPrimary`, aks holda `textFaint` rangida bo'ladi.
class NavBarItem extends StatelessWidget {
  final String iconAsset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const NavBarItem({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = selected ? c.textPrimary : c.textFaint;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.dp),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.dp, horizontal: 4.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 23.dp,
                height: 23.dp,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              SizedBox(height: 6.dp),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
