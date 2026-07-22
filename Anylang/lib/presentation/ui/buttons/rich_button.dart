import 'package:flutter/material.dart';

class RichButton extends StatelessWidget {
  final VoidCallback onTap;
  final EdgeInsets padding;
  final Widget? startIcon;
  final Widget? endIcon;
  final bool isLoading;
  final Color loadingCircleColor;
  final bool enabled;
  final String text;
  final TextAlign textAlign;
  final Color textColor;
  final BoxDecoration? decoration;
  final BorderRadius borderRadius;
  final TextStyle textStyle;
  final bool visibility;
  // true bo'lsa: start/end ikon text'ga yaqin (markazda) chiqadi.
  // false (default): text Expanded bo'lib, ikon chegaraga yaqin chiqadi.
  final bool iconNearText;

  const RichButton({
    super.key,
    required this.onTap,
    required this.text,
    this.isLoading = false,
    this.loadingCircleColor = Colors.white,
    this.enabled = true,
    this.textColor = Colors.black,
    this.textAlign = TextAlign.center,
    this.textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.decoration,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.startIcon,
    this.endIcon,
    this.visibility = true,
    this.iconNearText = false,
  });

  @override
  Widget build(BuildContext context) {
    return visibility ? IntrinsicHeight(
      child: Container(
        decoration: decoration ?? BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (isLoading || enabled == false) ? null : onTap,
            borderRadius: borderRadius,
            child: Padding(
              padding: padding,
              child: isLoading ? SizedBox(
                width: double.maxFinite,
                child: Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: loadingCircleColor,
                    ),
                  ),
                ),
              ) : iconNearText
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (startIcon != null) ...[startIcon!, SizedBox(width: 10)],

                        Flexible(
                          child: Text(
                            text,
                            textAlign: textAlign,
                            style: textStyle.copyWith(color: textColor),
                          ),
                        ),

                        if (endIcon != null) ...[SizedBox(width: 10), endIcon!],
                      ],
                    )
                  : Row(
                      children: [
                        ?startIcon,

                        if (startIcon != null) SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            text,
                            textAlign: textAlign,
                            style: textStyle.copyWith(color: textColor),
                          ),
                        ),

                        if (endIcon != null) SizedBox(width: 10),

                        ?endIcon,
                      ],
                    ),
            ),
          ),
        ),
      ),
    ) : SizedBox.shrink();
  }

}