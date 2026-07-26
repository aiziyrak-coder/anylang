import 'package:flutter/material.dart';
import '../../../data/core/mappers.dart';
import '../../ui/product_capabilities.dart';
import '../../ui/product_trust_badges.dart';

/// Bitta mahsulot (Bozor).
class Product {
  final int id;
  final String iconAsset;
  final LinearGradient tileGradient;
  final String name;
  final String? subtitle;
  final String price;
  final String views;
  final String? imageUrl;
  final List<String> imageUrls;
  final int sellerId;
  final bool isFavorited;
  final bool isTop;
  final String status;
  final String? topRequestStatus;
  final String? topPinnedUntil;
  final String? videoUrl;
  final String? factoryVideoUrl;
  final String? processVideoUrl;
  final String? moq;
  final String? shippingInfo;
  final List<String> shippingCountries;
  final double? rating;
  final int reviewsCount;
  final ProductTrustBadges trustBadges;
  final List<String> capabilities;

  const Product({
    required this.id,
    required this.iconAsset,
    required this.tileGradient,
    required this.name,
    required this.price,
    required this.views,
    this.subtitle,
    this.imageUrl,
    this.imageUrls = const [],
    this.sellerId = 0,
    this.isFavorited = false,
    this.isTop = false,
    this.status = 'published',
    this.topRequestStatus,
    this.topPinnedUntil,
    this.videoUrl,
    this.factoryVideoUrl,
    this.processVideoUrl,
    this.moq,
    this.shippingInfo,
    this.shippingCountries = const [],
    this.rating,
    this.reviewsCount = 0,
    this.trustBadges = const ProductTrustBadges(),
    this.capabilities = const [],
  });

  factory Product.fromApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final currency = (json['currency'] as String?) ?? 'USD';
    final priceRaw = json['price']?.toString() ?? '0';
    final imageUrls = <String>[];
    final imagesRaw = json['images'];
    if (imagesRaw is List) {
      for (final item in imagesRaw) {
        if (item is Map) {
          final url = item['url']?.toString();
          if (url != null && url.isNotEmpty) imageUrls.add(url);
        }
      }
    }
    final primaryUrl = json['primary_image_url'] as String?;
    if (primaryUrl != null &&
        primaryUrl.isNotEmpty &&
        !imageUrls.contains(primaryUrl)) {
      imageUrls.insert(0, primaryUrl);
    }
    final topReq = json['top_request'];
    String? topStatus;
    if (topReq is Map) {
      topStatus = topReq['status']?.toString();
    }
    final countriesRaw = json['shipping_countries'];
    final countries = <String>[];
    if (countriesRaw is List) {
      for (final c in countriesRaw) {
        final code = c.toString().trim().toUpperCase();
        if (code.isNotEmpty) countries.add(code);
      }
    }
    final seller = json['seller'];
    double? rating = (json['rating'] as num?)?.toDouble();
    var reviewsCount = (json['reviews_count'] as num?)?.toInt() ?? 0;
    if (seller is Map) {
      rating ??= (seller['rating'] as num?)?.toDouble();
      if (reviewsCount <= 0) {
        reviewsCount = (seller['reviews_count'] as num?)?.toInt() ?? 0;
      }
    }
    String? moq = (json['moq'] as String?)?.trim();
    if (moq == null || moq.isEmpty) {
      if (seller is Map) {
        moq = (seller['moq'] as String?)?.trim();
      }
    }
    var trust = ProductTrustBadges.fromApi(json['trust_badges']);
    if (!trust.hasAny && seller is Map) {
      trust = ProductTrustBadges.fromApi(seller['trust_badges']);
    }
    return Product(
      id: id,
      iconAsset: 'assets/icons/ic_prod_image.svg',
      tileGradient: productGradientFor(id),
      name: (json['name'] as String?) ?? '',
      subtitle: json['short_description'] as String?,
      price: formatPrice(priceRaw, currency),
      views: formatViews((json['views_count'] as num?)?.toInt() ?? 0),
      imageUrl: primaryUrl ?? (imageUrls.isNotEmpty ? imageUrls.first : null),
      imageUrls: imageUrls,
      sellerId: (json['seller_id'] as num?)?.toInt() ?? 0,
      isFavorited: json['is_favorited'] == true,
      isTop: json['is_top'] == true,
      status: (json['status'] as String?) ?? 'published',
      topRequestStatus: topStatus,
      topPinnedUntil: json['top_pinned_until']?.toString(),
      videoUrl: _optUrl(json['video_url']),
      factoryVideoUrl: _optUrl(json['factory_video_url']),
      processVideoUrl: _optUrl(json['process_video_url']),
      moq: (moq != null && moq.isNotEmpty) ? moq : null,
      shippingInfo: _optUrl(json['shipping_info']),
      shippingCountries: countries,
      rating: rating,
      reviewsCount: reviewsCount,
      trustBadges: trust,
      capabilities: parseProductCapabilities(json['capabilities']),
    );
  }

  static String? _optUrl(dynamic v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  Product copyWith({
    bool? isFavorited,
    bool? isTop,
    String? status,
    String? topRequestStatus,
    String? topPinnedUntil,
    ProductTrustBadges? trustBadges,
    List<String>? capabilities,
  }) {
    return Product(
      id: id,
      iconAsset: iconAsset,
      tileGradient: tileGradient,
      name: name,
      subtitle: subtitle,
      price: price,
      views: views,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      sellerId: sellerId,
      isFavorited: isFavorited ?? this.isFavorited,
      isTop: isTop ?? this.isTop,
      status: status ?? this.status,
      topRequestStatus: topRequestStatus ?? this.topRequestStatus,
      topPinnedUntil: topPinnedUntil ?? this.topPinnedUntil,
      videoUrl: videoUrl,
      factoryVideoUrl: factoryVideoUrl,
      processVideoUrl: processVideoUrl,
      moq: moq,
      shippingInfo: shippingInfo,
      shippingCountries: shippingCountries,
      rating: rating,
      reviewsCount: reviewsCount,
      trustBadges: trustBadges ?? this.trustBadges,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}
