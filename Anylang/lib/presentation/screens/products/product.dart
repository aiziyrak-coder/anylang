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
  final int sellerId;
  final bool isFavorited;

  const Product({
    required this.id,
    required this.iconAsset,
    required this.tileGradient,
    required this.name,
    required this.price,
    required this.views,
    this.subtitle,
    this.imageUrl,
    this.sellerId = 0,
    this.isFavorited = false,
  });

  factory Product.fromApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final currency = (json['currency'] as String?) ?? 'USD';
    final priceRaw = json['price']?.toString() ?? '0';
    return Product(
      id: id,
      iconAsset: 'assets/icons/ic_prod_image.svg',
      tileGradient: productGradientFor(id),
      name: (json['name'] as String?) ?? '',
      subtitle: json['short_description'] as String?,
      price: formatPrice(priceRaw, currency),
      views: formatViews((json['views_count'] as num?)?.toInt() ?? 0),
      imageUrl: json['primary_image_url'] as String?,
      sellerId: (json['seller_id'] as num?)?.toInt() ?? 0,
      isFavorited: json['is_favorited'] == true,
    );
  }
}
