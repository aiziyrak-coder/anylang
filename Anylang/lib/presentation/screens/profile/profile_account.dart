import 'package:flutter/material.dart';
import '../../ui/theme/gradients.dart';

/// Bitta o'z e'loni (biznes profilidagi "E'lonlarim" gridi). Umumiy `Product`
/// modelidan farqli — bu yerda ko'rishlar soni ko'rsatilmaydi (S14b dizayni).
class OwnListing {
  final LinearGradient tileGradient;
  final String name;
  final String price;

  const OwnListing({required this.tileGradient, required this.name, required this.price});
}

/// O'z profili ma'lumoti. `isBusiness=false` bo'lsa shaxsiy (obuna) profil
/// (S14a), `true` bo'lsa biznes (e'lonlar/statistika) profili (S14b)
/// ko'rsatiladi. Hozircha mock — keyin backenddan.
class ProfileAccount {
  final bool isBusiness;
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final bool verified;
  final String flagAsset;
  final String country;

  // Faqat shaxsiy:
  final String? username;
  final String? nativeLanguage;
  final String? memberSince;
  final String? subscriptionPlan;
  final String? subscriptionPeriod;
  final DateTime? subscriptionExpiresAt;

  // Faqat biznes:
  final String? role;
  final int? listingsCount;
  final String? viewsCount;
  final double? rating;
  final List<OwnListing> listings;

  const ProfileAccount({
    required this.isBusiness,
    required this.name,
    required this.initial,
    required this.avatarGradient,
    required this.flagAsset,
    required this.country,
    this.verified = false,
    this.username,
    this.nativeLanguage,
    this.memberSince,
    this.subscriptionPlan,
    this.subscriptionPeriod,
    this.subscriptionExpiresAt,
    this.role,
    this.listingsCount,
    this.viewsCount,
    this.rating,
    this.listings = const [],
  });
}

final ProfileAccount kMockPersonalAccount = ProfileAccount(
  isBusiness: false,
  name: 'Sardor Aliyev',
  initial: 'SA',
  avatarGradient: avatarTealGradient,
  flagAsset: 'assets/images/flag_uz.png',
  country: 'O‘zbekiston',
  username: '@sardor_a',
  nativeLanguage: 'O‘zbek tili',
  memberSince: 'Mart 2024',
  subscriptionPlan: 'Premium',
  subscriptionPeriod: '12 oy',
  subscriptionExpiresAt: DateTime(2026, 9, 12),
);

const kMockBusinessAccount = ProfileAccount(
  isBusiness: true,
  name: 'Anadolu Craft Co.',
  initial: 'A',
  avatarGradient: avatarBrownGradient,
  verified: true,
  flagAsset: 'assets/images/flag_tr.png',
  country: 'Turkiya',
  role: 'Ishlab chiqaruvchi',
  listingsCount: 8,
  viewsCount: '3.4k',
  rating: 4.9,
  listings: [
    OwnListing(tileGradient: prodTealGradient, name: 'Qo‘lda to‘qilgan sharf', price: '\$24.00'),
    OwnListing(tileGradient: prodBrownGradient, name: 'Charm qo‘l sumka', price: '\$79.00'),
    OwnListing(tileGradient: prodPurpleGradient, name: 'Mis choynak', price: '\$52.00'),
    OwnListing(tileGradient: prodBlueGradient, name: 'Kulolchilik lagan', price: '\$38.00'),
  ],
);
