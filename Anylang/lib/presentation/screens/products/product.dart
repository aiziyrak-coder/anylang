import 'package:flutter/material.dart';
import '../../ui/theme/gradients.dart';

/// Bitta mahsulot (Bozor). Hozircha mock — keyin backenddan.
class Product {
  final String iconAsset;             // rasm o'rniga placeholder ikon
  final LinearGradient tileGradient;  // karta fon gradienti
  final String name;
  final String? subtitle;             // grid kartasi uchun (masalan "Qo'lda bo'yalgan")
  final String price;                 // "$79.00"
  final String views;                 // ko'rishlar soni: "890", "1.2k"

  const Product({
    required this.iconAsset,
    required this.tileGradient,
    required this.name,
    required this.price,
    required this.views,
    this.subtitle,
  });
}

/// Top mahsulotlar (gorizontal). Keyinchalik so'rov bilan almashtiriladi.
const List<Product> kMockTopProducts = [
  Product(
    iconAsset: 'assets/icons/ic_prod_bag.svg',
    tileGradient: prodBrownGradient,
    name: 'Charm qo‘l sumka',
    price: '\$79.00',
    views: '890',
  ),
  Product(
    iconAsset: 'assets/icons/ic_prod_image.svg',
    tileGradient: prodTealGradient,
    name: 'Qo‘lda to‘qilgan sharf',
    price: '\$24.00',
    views: '1.2k',
  ),
];

/// Barcha mahsulotlar (grid). Keyinchalik so'rov bilan almashtiriladi.
const List<Product> kMockAllProducts = [
  Product(
    iconAsset: 'assets/icons/ic_prod_teapot.svg',
    tileGradient: prodBlueGradient,
    name: 'Seramika choynak',
    subtitle: 'Qo‘lda bo‘yalgan',
    price: '\$18.00',
    views: '340',
  ),
  Product(
    iconAsset: 'assets/icons/ic_prod_shirt.svg',
    tileGradient: prodPurpleGradient,
    name: 'Zig‘ir ko‘ylak',
    subtitle: 'Tabiiy mato',
    price: '\$45.00',
    views: '512',
  ),
  Product(
    iconAsset: 'assets/icons/ic_prod_goblet.svg',
    tileGradient: prodOliveGradient,
    name: 'Yog‘och kubok',
    subtitle: 'Zaytun daraxti',
    price: '\$32.00',
    views: '610',
  ),
  Product(
    iconAsset: 'assets/icons/ic_prod_box.svg',
    tileGradient: prodMaroonGradient,
    name: 'Ipak ro‘mol',
    subtitle: 'El bo‘yalgan',
    price: '\$28.00',
    views: '845',
  ),
];
