import 'package:flutter/material.dart';

/// Reusable container that draws a rounded dashed border around its child.
/// - No background by default (only the stroke), matching the current design.
/// - Customize strokeWidth, dashLength, dashGap, and borderRadius.
class DashedContainer extends StatelessWidget {
  const DashedContainer({
    super.key,
    required this.child,
    this.color,
    this.strokeWidth = 1.2,
    this.dashLength = 6,
    this.dashGap = 6,
    this.borderRadius = 12,
    this.padding,
  });

  final Widget child;
  final Color? color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final paintColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: paintColor,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        dashGap: dashGap,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.dashGap,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Inset so stroke is fully visible inside bounds
    final offset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset, offset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(borderRadius),
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        final extractEnd = next < metric.length ? next : metric.length;
        canvas.drawPath(metric.extractPath(distance, extractEnd), paint);
        distance = extractEnd + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.dashGap != dashGap ||
        oldDelegate.borderRadius != borderRadius;
  }
}

