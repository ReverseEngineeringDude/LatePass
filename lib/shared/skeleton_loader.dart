import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonContainer extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonContainer._({
    this.width = double.infinity,
    required this.height,
    this.borderRadius,
  });

  const SkeletonContainer.square({
    required double size,
    BorderRadius? borderRadius,
  }) : this._(width: size, height: size, borderRadius: borderRadius);

  const SkeletonContainer.rectangular({
    double width = double.infinity,
    required double height,
    BorderRadius? borderRadius,
  }) : this._(width: width, height: height, borderRadius: borderRadius);

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      highlightColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}
