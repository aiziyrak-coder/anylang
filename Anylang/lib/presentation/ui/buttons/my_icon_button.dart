import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class MyIconButton extends StatelessWidget {
  final VoidCallback onClick;
  final bool enabled;
  final Color? backgroundColor;
  final LinearGradient? backgroundGradient;
  final double borderRadius;
  final String? svgIcon;
  final String? imageIcon;
  final IconData? icon;
  final double iconSize;
  final Color? iconColor;
  final EdgeInsets padding;
  final BoxBorder? border;
  final double blurX;
  final double blurY;
  final List<BoxShadow>? boxShadow;


  const MyIconButton({
    super.key,
    required this.onClick,
    this.enabled = true,
    this.backgroundColor,
    this.backgroundGradient,
    this.borderRadius = 14,
    this.svgIcon,
    this.imageIcon,
    this.icon,
    this.iconSize = 24,
    this.iconColor = Colors.black,
    this.padding = const EdgeInsets.all(6),
    this.border,
    this.boxShadow,
    this.blurX = 0,
    this.blurY = 0,
  });

  @override
  Widget build(BuildContext context) {
    // boxShadow ClipRRect tashqarisida (aks holda soya kesilib ketadi).
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurX,
            sigmaY: blurY,
          ),
          child: Container(
            decoration: BoxDecoration(
                color: backgroundColor,
                gradient: backgroundGradient,
                borderRadius: BorderRadius.circular(borderRadius),
                border: border,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                  onTap: enabled ? onClick : null,
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Padding(
                    padding: padding,
                    child: svgIcon != null ? SvgPicture.asset(
                      svgIcon!,
                      width: iconSize,
                      height: iconSize,
                      colorFilter: iconColor != null
                          ? ColorFilter.mode(iconColor!, BlendMode.srcIn)
                          : null,
                    ) : (
                        imageIcon != null ? Image.asset(
                          imageIcon!,
                          width: iconSize,
                          height: iconSize,
                        ) : Icon(
                          icon,
                          size: iconSize,
                          color: iconColor,
                        )
                    ),
                  )
              ),
            ),
          ),
        ),
      ),
    );
  }
}