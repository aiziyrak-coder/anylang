import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// Ism ostidagi verifikatsiya CTA — yengil pulse + gradient shimmer.
class VerificationCtaButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool verified;
  final bool pending;

  const VerificationCtaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.verified = false,
    this.pending = false,
  });

  @override
  State<VerificationCtaButton> createState() => _VerificationCtaButtonState();
}

class _VerificationCtaButtonState extends State<VerificationCtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  bool get _animate => !widget.verified && !widget.pending;

  @override
  void initState() {
    super.initState();
    // To‘liq sikl: ~55% sweep + ~45% pauza (uchlarda “qotish” yo‘q).
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (_animate) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VerificationCtaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_animate && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    } else if (_animate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final verified = widget.verified;
    final pending = widget.pending;
    final radius = BorderRadius.circular(999.dp);

    final bg = verified
        ? c.accent.withValues(alpha: 0.16)
        : pending
            ? c.surface
            : c.accent;
    final fg = verified
        ? c.accentText
        : pending
            ? c.textPrimary
            : c.onAccent;
    final border = verified
        ? c.accent.withValues(alpha: 0.45)
        : pending
            ? c.surfaceBorder
            : c.accent;

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 10.dp),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified
                ? Icons.verified_rounded
                : pending
                    ? Icons.hourglass_top_rounded
                    : Icons.shield_moon_rounded,
            size: 18.dp,
            color: fg,
          ),
          SizedBox(width: 8.dp),
          Text(
            widget.label,
            style: TextStyle(
              color: fg,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    final buttonCore = Material(
      color: Colors.transparent,
      borderRadius: radius,
      // Ink + shimmer pill shaklida kesiladi (to‘rtburchak “quloqlar” yo‘q).
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: border, width: 1.2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_animate)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) =>
                        _ShimmerSweep(progress: _ctrl.value),
                  ),
                ),
              content,
            ],
          ),
        ),
      ),
    );

    // Shadow clip tashqarisida — Material clipBehavior soya kesib yubormasin.
    final button = verified
        ? buttonCore
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.28),
                  blurRadius: 16.dp,
                  offset: Offset(0, 6.dp),
                ),
              ],
            ),
            child: buttonCore,
          );

    if (!_animate) return button;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Uzluksiz sinus — bosh/oxirida to‘xtab qolmaydi.
        final scale = 1.0 + 0.028 * math.sin(_ctrl.value * 2 * math.pi);
        return Transform.scale(scale: scale, child: child);
      },
      child: button,
    );
  }
}

/// Gorizontal gradient “yorug‘lik” — chapdan o‘ngga, keyin pauza.
class _ShimmerSweep extends StatelessWidget {
  final double progress;

  const _ShimmerSweep({required this.progress});

  @override
  Widget build(BuildContext context) {
    // 0..0.58 — harakat (yumshoq sine), 0.58..1 — tiniq pauza.
    const sweepEnd = 0.58;
    final t = progress <= sweepEnd
        ? Curves.easeInOutSine.transform(progress / sweepEnd)
        : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) return const SizedBox.shrink();

        final bandW = math.max(w * 0.55, 48.dp);
        final x = (w + bandW) * t - bandW;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: x,
              top: -2,
              bottom: -2,
              width: bandW,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.42),
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.28, 0.5, 0.72, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tasdiqlangan ishonchlilik belgi (chip).
class TrustVerifiedMark extends StatelessWidget {
  const TrustVerifiedMark({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999.dp),
        border: Border.all(color: c.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 16.dp, color: c.accent),
          SizedBox(width: 6.dp),
          Text(
            'verification_trusted_mark'.tr,
            style: TextStyle(
              color: c.accentText,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
