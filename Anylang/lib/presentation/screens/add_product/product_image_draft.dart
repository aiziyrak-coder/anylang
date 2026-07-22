import 'package:flutter/material.dart';

/// Mahsulot qo'shish formasidagi bitta tanlangan rasm.
class ProductImageDraft {
  final LinearGradient gradient;
  final bool isPrimary;
  final String? filePath;

  const ProductImageDraft({
    required this.gradient,
    this.isPrimary = false,
    this.filePath,
  });
}
