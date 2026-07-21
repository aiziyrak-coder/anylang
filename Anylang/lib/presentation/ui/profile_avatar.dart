import 'package:flutter/material.dart';
import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// Shaxsiy profil — doira. Biznes profil — yumshoq kvadrat (squircle).
enum ProfileAvatarShape { circle, roundedSquare }

/// Profil avatari: gradient fon + bosh harf. Ixtiyoriy onlayn nuqta
/// (`online`) va tahrirlash tugmasi (`onEdit`) bilan. `user_profile` (boshqa
/// foydalanuvchi) va `profile` (o'z profili) ekranlarida qayta ishlatiladi.
class ProfileAvatar extends StatelessWidget {
  final String initial;
  final LinearGradient gradient;
  final ProfileAvatarShape shape;
  final double size;
  final bool online;
  final VoidCallback? onEdit;

  const ProfileAvatar({
    super.key,
    required this.initial,
    required this.gradient,
    this.shape = ProfileAvatarShape.circle,
    this.size = 88,
    this.online = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = size.dp;
    final borderRadius = shape == ProfileAvatarShape.circle
        ? BorderRadius.circular(s / 2)
        : BorderRadius.circular(s * 0.25);

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: s,
            height: s,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: gradient, borderRadius: borderRadius),
            child: Text(
              initial,
              style: TextStyle(color: kLime, fontSize: s * 0.38, fontWeight: FontWeight.w700),
            ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: s * 0.17,
                height: s * 0.17,
                decoration: BoxDecoration(
                  color: kOnline,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.background, width: 2.5.dp),
                ),
              ),
            ),
          if (onEdit != null)
            Positioned(
              right: -2.dp,
              bottom: -2.dp,
              child: Material(
                color: c.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onEdit,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(6.dp),
                    child: Icon(Icons.edit_rounded, size: 14.dp, color: c.onAccent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
