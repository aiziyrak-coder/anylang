import 'package:flutter/material.dart';
import '../../../data/core/mappers.dart';

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
    );
  }

  Product copyWith({
    bool? isFavorited,
    bool? isTop,
    String? status,
    String? topRequestStatus,
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
    );
  }
}
