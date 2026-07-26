import 'package:flutter/material.dart';

/// Mahsulot qo'shish formasidagi bitta tanlangan rasm.
class ProductImageDraft {
  final LinearGradient gradient;
  final bool isPrimary;
  final String? filePath;
  final int? imageId;
  final String? imageUrl;

  const ProductImageDraft({
    required this.gradient,
    this.isPrimary = false,
    this.filePath,
    this.imageId,
    this.imageUrl,
  });

  bool get hasLocalFile =>
      filePath != null && filePath!.trim().isNotEmpty;

  bool get hasNetwork =>
      imageUrl != null && imageUrl!.trim().isNotEmpty;
}
