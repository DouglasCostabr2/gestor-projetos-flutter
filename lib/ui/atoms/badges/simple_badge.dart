import 'package:flutter/material.dart';

/// Simple badge widget for displaying labels with customizable background and text colors
/// 
/// Example usage:
/// ```dart
/// SimpleBadge(
///   label: 'Logo',
///   backgroundColor: Colors.black.withOpacity(0.5),
///   textColor: Colors.grey.shade300,
/// )
/// ```
class SimpleBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const SimpleBadge({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.fontWeight,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0x80000000), // Black with 50% opacity
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize ?? 10,
          color: textColor ?? const Color(0xFFE0E0E0), // Light grey
          fontWeight: fontWeight ?? FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }
}

