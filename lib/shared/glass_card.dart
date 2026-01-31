import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Default color logic: White for light mode, Black/Navy for dark mode, but transparent-ish
    final baseColor = color ?? (isDark ? Colors.black : Colors.white);
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: baseColor.withOpacity(opacity),
            borderRadius: effectiveBorderRadius,
            border: Border.all(
              color: isDark 
                ? Colors.white.withOpacity(0.08) 
                : Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark 
                   ? Colors.black.withOpacity(0.2) 
                   : Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
