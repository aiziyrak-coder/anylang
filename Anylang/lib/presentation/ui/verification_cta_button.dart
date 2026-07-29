import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// Ism ostidagi verifikatsiya CTA — yengil pulse + shimmer.
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
  late final Animation<double> _pulse;
  late final Animation<double> _shine;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _pulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.045), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.045, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _shine = Tween<double>(begin: -1.2, end: 1.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic),
    );
    if (!widget.verified) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VerificationCtaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.verified && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    } else if (!widget.verified && !_ctrl.isAnimating) {
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

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final scale = verified ? 1.0 : _pulse.value;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(999.dp),
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999.dp),
              border: Border.all(color: border, width: 1.2),
              boxShadow: verified
                  ? null
                  : [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.28),
                        blurRadius: 16.dp,
                        offset: Offset(0, 6.dp),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999.dp),
              child: Stack(
                children: [
                  if (!verified && !pending)
                    AnimatedBuilder(
                      animation: _shine,
                      builder: (context, _) {
                        return Positioned.fill(
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment(_shine.value.clamp(-1.0, 1.0), 0),
                              child: Container(
                                width: 36.dp,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.dp,
                      vertical: 10.dp,
                    ),
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
