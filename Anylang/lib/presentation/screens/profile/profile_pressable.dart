import 'package:flutter/material.dart';

/// Tugma / chip bosilganda engil scale animatsiya.
class ProfilePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const ProfilePressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<ProfilePressable> createState() => _ProfilePressableState();
}

class _ProfilePressableState extends State<ProfilePressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(14);

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          onHighlightChanged: (v) {
            if (_pressed != v) setState(() => _pressed = v);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
