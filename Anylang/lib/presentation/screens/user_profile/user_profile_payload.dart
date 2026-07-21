import 'package:flutter/material.dart';
import '../../ui/theme/gradients.dart';

/// Boshqa foydalanuvchi profili uchun payload. `business` true bo'lsa biznes
/// ma'lumotlari (faoliyat, tajriba, sertifikat, e'lonlar) ko'rsatiladi.
class UserProfilePayload {
  final bool business;
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final bool verified;
  final String flagAsset;
  final String country;   // "Turkiya"
  final String role;      // biznes: "Ishlab chiqaruvchi", user: til nomi
  final String phone;

  // Faqat biznes:
  final String? experience;    // "12 yildan beri"
  final String? website;       // "anadolucraft.com"
  final int? completeness;     // 92
  final List<String> certificates;
  final int listings;

  const UserProfilePayload({
    required this.business,
    required this.name,
    required this.initial,
    required this.avatarGradient,
    required this.flagAsset,
    required this.country,
    required this.role,
    required this.phone,
    this.verified = false,
    this.experience,
    this.website,
    this.completeness,
    this.certificates = const [],
    this.listings = 0,
  });
}

/// Namuna biznes profili (mahsulot info'sidagi biznesga mos).
const UserProfilePayload kAnadoluBusinessProfile = UserProfilePayload(
  business: true,
  name: 'Anadolu Craft Co.',
  initial: 'A',
  avatarGradient: avatarBrownGradient,
  verified: true,
  flagAsset: 'assets/images/flag_tr.png',
  country: 'Turkiya',
  role: 'Ishlab chiqaruvchi',
  phone: '+90 212 555 04 18',
  experience: '12 yildan beri',
  website: 'anadolucraft.com',
  completeness: 92,
  certificates: ['ISO 9001', 'CE Mark'],
  listings: 8,
);
