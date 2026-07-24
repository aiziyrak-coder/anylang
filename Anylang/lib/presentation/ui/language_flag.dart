import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/local/flag_cache_service.dart';
import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// Bayroq: birinchi marta URL dan yuklab diskka cache, keyin lokal.
class LanguageFlag extends StatefulWidget {
  final String? url;
  final String? emoji;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const LanguageFlag({
    super.key,
    this.url,
    this.emoji,
    this.width = 20,
    this.height = 14,
    this.borderRadius,
  });

  @override
  State<LanguageFlag> createState() => _LanguageFlagState();
}

class _LanguageFlagState extends State<LanguageFlag> {
  File? _file;
  bool _loading = true;
  String? _loadedUrl;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant LanguageFlag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final u = (widget.url ?? '').trim();
    if (u.isEmpty) {
      if (mounted) {
        setState(() {
          _file = null;
          _loading = false;
          _loadedUrl = u;
        });
      }
      return;
    }
    if (_loadedUrl == u && _file != null) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadedUrl = u;
      });
    }
    File? file;
    try {
      if (Get.isRegistered<FlagCacheService>()) {
        file = await Get.find<FlagCacheService>().getFile(u);
      }
    } catch (_) {
      file = null;
    }
    if (!mounted || _loadedUrl != u) return;
    setState(() {
      _file = file;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = widget.borderRadius ?? BorderRadius.circular(3.dp);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: _file != null
            ? Image.file(
                _file!,
                width: widget.width,
                height: widget.height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(c),
              )
            : _loading
                ? ColoredBox(color: c.surfaceBorder.withValues(alpha: 0.25))
                : _fallback(c),
      ),
    );
  }

  Widget _fallback(AppColors c) {
    final e = (widget.emoji ?? '').trim();
    if (e.isNotEmpty) {
      return ColoredBox(
        color: c.surfaceBorder.withValues(alpha: 0.35),
        child: Center(
          child: Text(e, style: TextStyle(fontSize: widget.height * 0.65)),
        ),
      );
    }
    return ColoredBox(
      color: c.surfaceBorder.withValues(alpha: 0.35),
      child: Center(
        child: Icon(
          Icons.language,
          size: widget.height * 0.75,
          color: c.textSecondary,
        ),
      ),
    );
  }
}
