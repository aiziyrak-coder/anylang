import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/size_controller.dart';
import 'theme/colors.dart';
import 'theme/gradients.dart';

/// Bozor — qidiruv ostidagi aylanuvchi promo banner.
class MarketPromoBanner extends StatefulWidget {
  final ValueChanged<String> onTap;

  const MarketPromoBanner({super.key, required this.onTap});

  static const slides = <({String id, String emoji, String titleKey})>[
    (id: 'uz_export', emoji: '🇺🇿', titleKey: 'market_banner_uz_export'),
    (id: 'china_factory', emoji: '🇨🇳', titleKey: 'market_banner_china_factory'),
    (id: 'deals', emoji: '🔥', titleKey: 'market_banner_deals'),
    (id: 'ai_recommended', emoji: '🎯', titleKey: 'market_banner_ai'),
  ];

  @override
  State<MarketPromoBanner> createState() => _MarketPromoBannerState();
}

class _MarketPromoBannerState extends State<MarketPromoBanner> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % MarketPromoBanner.slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  LinearGradient _gradientFor(int i) {
    switch (i % 4) {
      case 0:
        return marketBannerGradientA;
      case 1:
        return marketBannerGradientB;
      case 2:
        return marketBannerGradientC;
      default:
        return marketBannerGradientD;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16.dp);

    return Column(
      children: [
        SizedBox(
          height: 88.dp,
          child: PageView.builder(
            controller: _controller,
            itemCount: MarketPromoBanner.slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final slide = MarketPromoBanner.slides[i];
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.dp),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onTap(slide.id),
                    borderRadius: radius,
                    child: Ink(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.dp,
                        vertical: 14.dp,
                      ),
                      decoration: BoxDecoration(
                        gradient: _gradientFor(i),
                        borderRadius: radius,
                        border: Border.all(
                          color: c.surfaceBorder.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(slide.emoji, style: TextStyle(fontSize: 28.sp)),
                          SizedBox(width: 12.dp),
                          Expanded(
                            child: Text(
                              slide.titleKey.tr,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 22.dp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8.dp),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < MarketPromoBanner.slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: EdgeInsets.symmetric(horizontal: 3.dp),
                width: i == _index ? 16.dp : 6.dp,
                height: 6.dp,
                decoration: BoxDecoration(
                  color: i == _index
                      ? c.accent
                      : c.outline.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(99.dp),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
