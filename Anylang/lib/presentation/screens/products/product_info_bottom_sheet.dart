import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/full_screen_image_dialog.dart';
import '../../screens/chat/chat_payload.dart';
import '../../screens/chat/chat_screen.dart';
import '../../utils/app_snackbar.dart';
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

// Galereya — rasm URL'lari; bo'sh bo'lsa gradient fallback.
List<String> _galleryUrls(Product p) {
  if (p.imageUrls.isNotEmpty) return p.imageUrls;
  final primary = p.imageUrl?.trim();
  if (primary != null && primary.isNotEmpty) return [primary];
  return const [];
}

class _ProductInfoSheet extends StatefulWidget {
  final Product product;
  final VoidCallback onOpenBusiness;
  const _ProductInfoSheet({required this.product, required this.onOpenBusiness});

  @override
  State<_ProductInfoSheet> createState() => _ProductInfoSheetState();
}

class _ProductInfoSheetState extends State<_ProductInfoSheet> {
  int _selected = 0;
  late bool _fav;
  bool _favLoading = false;
  bool _contacting = false;
  bool _topBusy = false;
  late Product _product;
  String _description = '';
  List<String> _attributes = const [];
  String? _sellerName;
  String? _sellerRole;
  String? _sellerAvatar;
  bool _sellerLoading = false;
  bool _detailErrorShown = false;

  bool get _isOwner {
    final me = SessionStore.userId();
    return me != null && me > 0 && me == _product.sellerId;
  }

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _fav = widget.product.isFavorited;
    _description = widget.product.subtitle ?? '';
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final result = await Get.find<ProductsRepository>().detail(_product.id);
    final map = asMap(result.dataOrNull);
    if (map != null && mounted) {
      setState(() {
        _product = Product.fromApi(map);
        _description = (map['description'] as String?)?.trim().isNotEmpty == true
            ? map['description'] as String
            : (_product.subtitle ?? '');
        final attrs = map['attributes'];
        if (attrs is List) {
          _attributes = attrs.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        }
        _fav = _product.isFavorited;
      });
    } else if (result.errorOrNull != null && mounted && !_detailErrorShown) {
      _detailErrorShown = true;
      showAppError(result.errorOrNull!);
    }
    final sellerId = _product.sellerId;
    if (sellerId > 0) {
      setState(() => _sellerLoading = true);
      final profile = await Get.find<ProfileRepository>().getPublicUser(sellerId);
      final pmap = asMap(profile.dataOrNull);
      if (!mounted) return;
      setState(() {
        _sellerLoading = false;
        if (pmap != null) {
          _sellerName = (pmap['full_name'] as String?) ??
              (pmap['name'] as String?) ??
              'product_seller_unknown'.tr;
          final biz = pmap['business'] as Map?;
          _sellerRole = biz?['business_role']?.toString() ??
              pmap['subtitle_role']?.toString() ??
              '';
          _sellerAvatar = pmap['is_business'] == true
              ? (biz?['logo_url'] as String?)
              : (pmap['avatar_url'] as String?);
        } else if (profile.errorOrNull != null) {
          _sellerName = 'product_seller_unknown'.tr;
        }
      });
    }
  }

  Future<void> _contactSeller() async {
    if (_contacting) return;
    final sellerId = _product.sellerId;
    if (sellerId <= 0) {
      showAppError('product_contact_unavailable'.tr);
      return;
    }
    _contacting = true;
    Navigator.of(context).pop();

    final chatResult = await Get.find<ChatRepository>().createChat(sellerId);
    if (chatResult.errorOrNull != null) {
      showAppError(chatResult.errorOrNull!);
      _contacting = false;
      return;
    }
    final map = asMap(chatResult.dataOrNull);
    final chatId = (map?['id'] as num?)?.toInt() ?? 0;
    if (chatId <= 0) {
      showAppError('chat_profile_unavailable'.tr);
      _contacting = false;
      return;
    }

    var name = 'User';
    var initial = '?';
    var gradient = avatarGradientFor(sellerId);
    var online = false;
    String? avatarUrl;

    final profileResult =
        await Get.find<ProfileRepository>().getPublicUser(sellerId);
    profileResult.when(
      success: (profileData) {
        final profile = asMap(profileData);
        if (profile == null) return;
        name = profile['full_name']?.toString() ?? name;
        initial = initialsOf(name);
        online = profile['is_online'] == true;
        avatarUrl = profile['avatar_url']?.toString();
      },
      failure: (_) {},
    );

    final ctx = Get.context;
    if (ctx != null && ctx.mounted) {
      final screen = ChatScreen();
      screen.payload = ChatPayload(
        chatId: chatId,
        peerId: sellerId,
        name: name,
        initial: initial,
        avatarGradient: gradient,
        online: online,
        avatarUrl: avatarUrl,
      );
      await Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => screen.build()),
      );
    }
    _contacting = false;
  }

  Future<void> _toggleFavorite() async {
    if (_favLoading || _product.id <= 0) return;
    HapticFeedback.lightImpact();
    final wasFav = _fav;
    setState(() {
      _fav = !wasFav;
      _favLoading = true;
    });
    final repo = Get.find<ProductsRepository>();
    final result = wasFav
        ? await repo.unfavorite(_product.id)
        : await repo.favorite(_product.id);
    if (!mounted) return;
    result.when(
      success: (_) {},
      failure: (err) {
        setState(() => _fav = wasFav);
        showAppError(err);
      },
    );
    setState(() => _favLoading = false);
  }

  Future<void> _requestTop() async {
    if (_topBusy || _product.id <= 0) return;
    setState(() => _topBusy = true);
    final result = await Get.find<ProductsRepository>().requestTop(_product.id);
    if (!mounted) return;
    setState(() => _topBusy = false);
    if (result.errorOrNull != null) {
      showAppError(result.errorOrNull);
      return;
    }
    final map = asMap(result.dataOrNull);
    setState(() {
      _product = _product.copyWith(
        topRequestStatus: map?['status']?.toString() ?? 'pending',
      );
    });
  }

  Future<void> _cancelTopRequest() async {
    if (_topBusy || _product.id <= 0) return;
    setState(() => _topBusy = true);
    final result =
        await Get.find<ProductsRepository>().cancelTopRequest(_product.id);
    if (!mounted) return;
    setState(() => _topBusy = false);
    if (result.errorOrNull != null) {
      showAppError(result.errorOrNull);
      return;
    }
    setState(() {
      _product = _product.copyWith(topRequestStatus: 'cancelled');
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final gallery = _galleryUrls(_product);
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
                    _image(c, gallery, _selected),
                    SizedBox(height: 12.dp),
                    _thumbnails(c, gallery),
                    SizedBox(height: 18.dp),
                    _titlePrice(c),
                    if (_attributes.isNotEmpty) ...[
                      SizedBox(height: 12.dp),
                      _chips(c),
                    ],
                    if (_description.isNotEmpty) ...[
                      SizedBox(height: 14.dp),
                      Text(
                        _description,
                        style: TextStyle(color: c.textSecondary, fontSize: 14.sp, height: 1.5),
                      ),
                    ],
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

  Widget _image(AppColors c, List<String> gallery, int selectedIndex) {
    final url = gallery.isNotEmpty ? gallery[selectedIndex.clamp(0, gallery.length - 1)] : null;
    return AspectRatio(
      aspectRatio: 364 / 210,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.dp),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(gradient: _product.tileGradient)),
            if (url != null && url.isNotEmpty)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: SvgPicture.asset(
                    'assets/icons/ic_prod_image.svg',
                    width: 46.dp,
                    height: 46.dp,
                  ),
                ),
              )
            else
              Center(
                child: SvgPicture.asset(
                  'assets/icons/ic_prod_image.svg',
                  width: 46.dp,
                  height: 46.dp,
                ),
              ),
            if (url != null && url.isNotEmpty)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => showFullScreenImage(context, url: url),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            Positioned(
              top: 12.dp,
              right: 12.dp,
              child: IgnorePointer(
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
                        '${_product.views} ${'products_views'.tr}',
                        style: TextStyle(color: kAvatarFg, fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnails(AppColors c, List<String> gallery) {
    if (gallery.isEmpty) {
      return Row(
        children: [
          Container(
            width: 58.dp,
            height: 58.dp,
            decoration: BoxDecoration(
              gradient: _product.tileGradient,
              borderRadius: BorderRadius.circular(12.dp),
              border: Border.all(color: c.accent, width: 2.dp),
            ),
          ),
        ],
      );
    }
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
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: _product.tileGradient,
                  borderRadius: BorderRadius.circular(12.dp),
                  border: Border.all(
                    color: i == _selected ? c.accent : Colors.transparent,
                    width: 2.dp,
                  ),
                ),
                child: Image.network(
                  gallery[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: SvgPicture.asset(
                      'assets/icons/ic_prod_image.svg',
                      width: 22.dp,
                      height: 22.dp,
                    ),
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
            _product.name,
            style: TextStyle(color: c.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(width: 12.dp),
        Text(
          _product.price,
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
    final name = _sellerLoading
        ? '…'
        : (_sellerName ?? 'product_seller_unknown'.tr);
    final role = _sellerRole ?? '';
    final initial = initialsOf(name);
    final gradient = avatarGradientFor(_product.sellerId);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16.dp),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.dp),
        onTap: () {
          Navigator.pop(context);
          widget.onOpenBusiness();
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                  image: _sellerAvatar != null && _sellerAvatar!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_sellerAvatar!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _sellerAvatar == null || _sellerAvatar!.isEmpty
                    ? Text(
                        initial,
                        style: TextStyle(
                          color: kLime,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (role.isNotEmpty)
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textFaint),
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
          if (!_isOwner) ...[
            Material(
              color: c.surface,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: _favLoading ? null : _toggleFavorite,
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
                          colorFilter: ColorFilter.mode(
                            c.textSecondary,
                            BlendMode.srcIn,
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(width: 12.dp),
            Expanded(
              child: RichButton(
                text: 'product_contact'.tr,
                onTap: _contactSeller,
                iconNearText: true,
                startIcon: SvgPicture.asset(
                  'assets/icons/ic_contact.svg',
                  width: 20.dp,
                  height: 20.dp,
                ),
                textColor: c.onAccent,
                textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
                padding: EdgeInsets.symmetric(vertical: 15.dp, horizontal: 16.dp),
                borderRadius: radius,
                decoration: BoxDecoration(
                  gradient: limeButtonGradient,
                  borderRadius: radius,
                ),
              ),
            ),
          ] else
            Expanded(child: _ownerTopAction(c, radius)),
        ],
      ),
    );
  }

  Widget _ownerTopAction(AppColors c, BorderRadius radius) {
    if (_product.isTop) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 15.dp, horizontal: 16.dp),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: c.outline),
        ),
        child: Text(
          'product_already_top'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final status = _product.topRequestStatus;
    if (status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 15.dp, horizontal: 12.dp),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: c.outline),
              ),
              child: Text(
                'product_top_pending'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.dp),
          Material(
            color: c.surface,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: _topBusy ? null : _cancelTopRequest,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: c.outline),
                ),
                padding: EdgeInsets.symmetric(vertical: 15.dp, horizontal: 14.dp),
                child: Text(
                  'product_top_cancel'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (_product.status != 'published') {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 15.dp, horizontal: 16.dp),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: c.outline),
        ),
        child: Text(
          'product_top_publish_first'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return RichButton(
      text: 'product_request_top'.tr,
      onTap: _topBusy ? () {} : _requestTop,
      textColor: c.onAccent,
      textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
      padding: EdgeInsets.symmetric(vertical: 15.dp, horizontal: 16.dp),
      borderRadius: radius,
      decoration: BoxDecoration(
        gradient: limeButtonGradient,
        borderRadius: radius,
      ),
    );
  }
}
