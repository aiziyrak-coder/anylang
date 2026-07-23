import 'package:flutter/material.dart';
import '../glass_surface.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Biznes profilidagi statistik ko'rsatkich kartasi (masalan "8 E'lonlar").
class ProfileStatCard extends StatelessWidget {
  final String value;
  final String label;

  const ProfileStatCard({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return GlassSurface(
      borderRadius: BorderRadius.circular(16.dp),
      padding: EdgeInsets.symmetric(vertical: 14.dp),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2.dp),
          Text(
            label,
            style: TextStyle(color: c.textFaint, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}
