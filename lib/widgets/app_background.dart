import 'dart:ui';

import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF090E14) : const Color(0xFFEFF4FF);

    Widget content = Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base,
                  isDark ? const Color(0xFF0F1A25) : const Color(0xFFF9FCFF),
                ],
              ),
            ),
          ),
        ),
        const _AmbientBlob(top: -100, left: -70, size: 240),
        const _AmbientBlob(top: 280, right: -110, size: 240),
        Positioned.fill(child: child),
      ],
    );

    return content;
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final double size;
  final double? top;
  final double? left;
  final double? right;

  const _AmbientBlob({
    required this.size,
    this.top,
    this.left,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = isDark ? const Color(0xFFBA6A22) : const Color(0xFFFFBE77);
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                tint.withValues(alpha: 0.42),
                tint.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
