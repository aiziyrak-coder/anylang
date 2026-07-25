import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../product_video_badge.dart';
import '../product_trust_badges.dart';
import '../product_trust_badges_view.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// "Top mahsulotlar" gorizontal ro'yxatining kartasi (TOP badge bilan).
class ProductTopCard extends StatelessWidget {
  final String iconAsset;
  final LinearGradient tileGradient;
  final String name;
  final String price;
  final String views;
  final String? imageUrl;
  final bool hasVideo;
  final ProductTrustBadges trustBadges;
  final VoidCallback onTap;
  final VoidCallback? onVideoTap;

  const ProductTopCard({
    super.key,
    required this.iconAsset,
    required this.tileGradient,
    required this.name,
    required this.price,
    required this.views,
    required this.onTap,
    this.imageUrl,
    this.hasVideo = false,
    this.trustBadges = const ProductTrustBadges(),
    this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(18.dp);
    final url = imageUrl?.trim();

    return SizedBox(
      width: 182.dp,
      child: Material(
        color: c.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 120.dp,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(decoration: BoxDecoration(gradient: tileGradient)),
                    ),
                    if (url != null && url.isNotEmpty)
                      Positioned.fill(
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: SvgPicture.asset(iconAsset, width: 34.dp, height: 34.dp),
                          ),
                        ),
                      )
                    else
                      Center(child: SvgPicture.asset(iconAsset, width: 34.dp, height: 34.dp)),
                    Positioned(
                      top: 10.dp,
                      left: 10.dp,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 9.dp, vertical: 3.dp),
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(99.dp),
                        ),
                        child: Text(
                          'TOP',
                          style: TextStyle(
                            color: c.onAccent,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (hasVideo)
                      Positioned(
                        left: 10.dp,
                        bottom: 10.dp,
                        child: ProductVideoBadge(
                          compact: true,
                          onTap: onVideoTap,
                        ),
                      ),
                    if (trustBadges.hasAny)
                      Positioned(
                        left: 8.dp,
                        right: 8.dp,
                        top: 36.dp,
                        child: ProductTrustBadgesView(
                          data: trustBadges,
                          compact: true,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12.dp, 10.dp, 12.dp, 12.dp),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6.dp),
                    Row(
                      children: [
                        Text(
                          price,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        SvgPicture.asset(
                          'assets/icons/ic_eye.svg',
                          width: 13.dp,
                          height: 13.dp,
                          colorFilter: ColorFilter.mode(c.textFaint, BlendMode.srcIn),
                        ),
                        SizedBox(width: 4.dp),
                        Text(
                          views,
                          style: TextStyle(color: c.textFaint, fontSize: 11.sp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
