import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../ui/buttons/rich_button.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/size_controller.dart';
import 'product.dart';

/// S11 — mahsulot ma'lumoti bottom sheet. Joriy oyna ustida ochiladi.
/// `onOpenBusiness` — biznes kartasi bosilganda (sheet yopilib) chaqiriladi.
Future<void> showProductInfoBottomSheet(
  BuildContext context,
  Product product, {
  required VoidCallback onOpenBusiness,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _ProductInfoSheet(product: product, onOpenBusiness: onOpenBusiness),
  );
}

// Demo galereya (rasm o'rniga gradientlar) — birinchisi mahsulotning o'zi.
List<LinearGradient> _gallery(Product p) => [p.tileGradient, prodBlueGradient, prodPurpleGradient];

// Mock atribut/tavsif/biznes — keyinchalik backenddan.
const List<String> _attributes = ['Material: 100% jun', 'Rang: Bej', 'Uzunlik: 180 sm'];
const String _description =
    'Anadolu tog‘larida qo‘lda to‘qilgan tabiiy jun sharf. Yumshoq, issiq va nafas '
    'oladi. Har bir dona alohida ustalar tomonidan tayyorlanadi — naqshlar takrorlanmas.';

class _ProductInfoSheet extends StatefulWidget {
  final Product product;
  final VoidCallback onOpenBusiness;
  const _ProductInfoSheet({required this.product, required this.onOpenBusiness});

  @override
  State<_ProductInfoSheet> createState() => _ProductInfoSheetState();
}

class _ProductInfoSheetState extends State<_ProductInfoSheet> {
  int _selected = 0;
  bool _fav = false;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final gallery = _gallery(widget.product);
    final maxH = MediaQuery.of(context).size.height * 0.92;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.dp),
            Container(
              width: 40.dp,
              height: 4.dp,
              decoration: BoxDecoration(
                color: c.textFaint,
                borderRadius: BorderRadius.circular(2.dp),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18.dp, 16.dp, 18.dp, 16.dp),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _image(c, gallery[_selected]),
                    SizedBox(height: 12.dp),
                    _thumbnails(c, gallery),
                    SizedBox(height: 18.dp),
                    _titlePrice(c),
                    SizedBox(height: 12.dp),
                    _chips(c),
                    SizedBox(height: 14.dp),
                    Text(
                      _description,
                      style: TextStyle(color: c.textSecondary, fontSize: 14.sp, height: 1.5),
                    ),
                    SizedBox(height: 16.dp),
                    _businessCard(c),
                  ],
                ),
              ),
            ),
            _bottomBar(c),
          ],
        ),
      ),
    );
  }

  Widget _image(AppColors c, LinearGradient g) {
    return AspectRatio(
      aspectRatio: 364 / 210,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(18.dp)),
        child: Stack(
          children: [
            Center(
              child: SvgPicture.asset('assets/icons/ic_prod_image.svg', width: 46.dp, height: 46.dp),
            ),
            // Ko'rishlar belgisi
            Positioned(
              top: 12.dp,
              right: 12.dp,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 5.dp),
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(99.dp),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/ic_eye.svg',
                      width: 13.dp,
                      height: 13.dp,
                      colorFilter: ColorFilter.mode(c.accent, BlendMode.srcIn),
                    ),
                    SizedBox(width: 5.dp),
                    Text(
                      '${widget.product.views} ${'products_views'.tr}',
                      style: TextStyle(color: kAvatarFg, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ),
            // Sahifa nuqtalari
            Positioned(
              bottom: 10.dp,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_gallery(widget.product).length, (i) {
                  final active = i == _selected;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(horizontal: 3.dp),
                    width: active ? 18.dp : 6.dp,
                    height: 6.dp,
                    decoration: BoxDecoration(
                      color: active ? c.accent : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(99.dp),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnails(AppColors c, List<LinearGradient> gallery) {
    return Row(
      children: [
        for (int i = 0; i < gallery.length; i++) ...[
          if (i > 0) SizedBox(width: 10.dp),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12.dp),
              onTap: () => setState(() => _selected = i),
              child: Container(
                width: 58.dp,
                height: 58.dp,
                decoration: BoxDecoration(
                  gradient: gallery[i],
                  borderRadius: BorderRadius.circular(12.dp),
                  border: Border.all(
                    color: i == _selected ? c.accent : Colors.transparent,
                    width: 2.dp,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _titlePrice(AppColors c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            widget.product.name,
            style: TextStyle(color: c.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(width: 12.dp),
        Text(
          widget.product.price,
          style: TextStyle(color: c.textPrimary, fontSize: 22.sp, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _chips(AppColors c) {
    return Wrap(
      spacing: 8.dp,
      runSpacing: 8.dp,
      children: [
        for (final a in _attributes)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 6.dp),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(99.dp),
              border: Border.all(color: c.outline),
            ),
            child: Text(a, style: TextStyle(color: c.textSecondary, fontSize: 12.sp)),
          ),
      ],
    );
  }

  Widget _businessCard(AppColors c) {
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16.dp),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.dp),
        onTap: () {
          Navigator.pop(context); // sheet yopiladi
          widget.onOpenBusiness(); // biznes profiliga o'tiladi (S12)
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.dp),
            border: Border.all(color: c.outline),
          ),
          padding: EdgeInsets.all(10.dp),
          child: Row(
            children: [
              Container(
                width: 44.dp,
                height: 44.dp,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: avatarBrownGradient),
                child: Text(
                  'A',
                  style: TextStyle(color: kLime, fontSize: 16.sp, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Anadolu Craft Co.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w700),
                          ),
                        ),
                        SizedBox(width: 5.dp),
                        SvgPicture.asset('assets/icons/ic_verified.svg', width: 15.dp, height: 15.dp),
                      ],
                    ),
                    SizedBox(height: 2.dp),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3.dp),
                          child: Image.asset('assets/images/flag_tr.png', width: 18.dp, height: 13.dp, fit: BoxFit.cover),
                        ),
                        SizedBox(width: 6.dp),
                        Text(
                          'Turkiya · Ishlab chiqaruvchi',
                          style: TextStyle(color: c.textFaint, fontSize: 12.sp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.textFaint, size: 22.dp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(AppColors c) {
    final radius = BorderRadius.circular(15.dp);
    return Container(
      padding: EdgeInsets.fromLTRB(18.dp, 12.dp, 18.dp, 12.dp),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.outline)),
      ),
      child: Row(
        children: [
          // Sevimli (heart)
          Material(
            color: c.surface,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: () => setState(() => _fav = !_fav),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: c.outline),
                ),
                padding: EdgeInsets.all(15.dp),
                child: _fav
                    ? Icon(Icons.favorite, color: c.accent, size: 22.dp)
                    : SvgPicture.asset(
                        'assets/icons/ic_heart.svg',
                        width: 22.dp,
                        height: 22.dp,
                        colorFilter: ColorFilter.mode(c.textSecondary, BlendMode.srcIn),
                      ),
              ),
            ),
          ),
          SizedBox(width: 12.dp),
          // Bog'lanish
          Expanded(
            child: RichButton(
              text: 'product_contact'.tr,
              onTap: () {}, // TODO: sotuvchi bilan bog'lanish
              iconNearText: true,
              startIcon: SvgPicture.asset('assets/icons/ic_contact.svg', width: 20.dp, height: 20.dp),
              textColor: c.onAccent,
              textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
              padding: EdgeInsets.symmetric(vertical: 15.dp, horizontal: 16.dp),
              borderRadius: radius,
              decoration: BoxDecoration(gradient: limeButtonGradient, borderRadius: radius),
            ),
          ),
        ],
      ),
    );
  }
}
