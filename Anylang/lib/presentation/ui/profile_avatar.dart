import 'package:flutter/material.dart';
import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// Shaxsiy / biznes — doira avatar (rasm yoki bosh harf).
enum ProfileAvatarShape { circle, roundedSquare }

/// Profil avatari: gradient + harf; `imageUrl` bo‘lsa doira ichida rasm.
/// Theme almashtirilganda rasm yo‘qolmasligi uchun loadingda initialga qaytmaydi.
class ProfileAvatar extends StatelessWidget {
  final String initial;
  final LinearGradient gradient;
  final String? imageUrl;
  final ProfileAvatarShape shape;
  final double size;
  final bool online;
  final VoidCallback? onEdit;

  const ProfileAvatar({
    super.key,
    required this.initial,
    required this.gradient,
    this.imageUrl,
    this.shape = ProfileAvatarShape.circle,
    this.size = 88,
    this.online = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = size.dp;
    // Har doim doira — light/dark va barcha ekranlarda bir xil.
    final borderRadius = BorderRadius.circular(s / 2);

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _avatarBody(c, s, borderRadius),
          if (online)
            Positioned(
              right: -1.dp,
              bottom: -1.dp,
              child: Container(
                width: (s * 0.28).clamp(12.dp, 18.dp),
                height: (s * 0.28).clamp(12.dp, 18.dp),
                decoration: BoxDecoration(
                  color: kOnline,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.background, width: 2.dp),
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
                    child: Icon(
                      Icons.edit_rounded,
                      size: 14.dp,
                      color: c.onAccent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarBody(AppColors c, double s, BorderRadius borderRadius) {
    final url = imageUrl?.trim();
    final fallback = _initialBody(c, s, borderRadius);
    if (url == null || url.isEmpty) return fallback;

    return ClipOval(
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          fit: StackFit.expand,
          children: [
            fallback,
            Image.network(
              url,
              key: ValueKey(url),
              width: s,
              height: s,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialBody(AppColors c, double s, BorderRadius borderRadius) {
    return Container(
      width: s,
      height: s,
      alignment: Alignment.center,
      decoration: BoxDecoration(gradient: gradient, borderRadius: borderRadius),
      child: Text(
        initial,
        style: TextStyle(
          color: kLime,
          fontSize: s * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
