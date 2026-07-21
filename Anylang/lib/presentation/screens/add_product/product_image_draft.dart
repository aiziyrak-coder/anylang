import 'package:flutter/material.dart';

/// Mahsulot qo'shish formasidagi bitta tanlangan rasm. Birinchi qo'shilgan
/// rasm avtomatik "Asosiy" bo'ladi.
class ProductImageDraft {
  final LinearGradient gradient;
  final bool isPrimary;

  const ProductImageDraft({required this.gradient, this.isPrimary = false});
}
