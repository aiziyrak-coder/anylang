import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// "Barcha mahsulotlar" gridining kartasi (nom + subtitle + narx + ko'rish).
class ProductGridCard extends StatelessWidget {
  final String iconAsset;
  final LinearGradient tileGradient;
  final String name;
  final String? subtitle;
  final String price;
  final String views;
  final String? imageUrl;
  final VoidCallback onTap;

  const ProductGridCard({
    super.key,
    required this.iconAsset,
    required this.tileGradient,
    required this.name,
    required this.price,
    required this.views,
    required this.onTap,
    this.subtitle,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16.dp);
    final url = imageUrl?.trim();

    return Material(
      color: c.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(decoration: BoxDecoration(gradient: tileGradient)),
                  if (url != null && url.isNotEmpty)
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: SvgPicture.asset(iconAsset, width: 28.dp, height: 28.dp),
                      ),
                    )
                  else
                    Center(child: SvgPicture.asset(iconAsset, width: 28.dp, height: 28.dp)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.dp, 10.dp, 12.dp, 12.dp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2.dp),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textFaint, fontSize: 11.sp),
                    ),
                  ],
                  SizedBox(height: 6.dp),
                  Row(
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          '$views ${'products_views'.tr}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(color: c.textFaint, fontSize: 11.sp),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
