import 'dart:ui';
import 'package:flutter/material.dart';

/// A glassmorphic container widget that creates a frosted glass effect.
/// 
/// This widget implements glassmorphism design principles:
/// - Translucency through opacity
/// - Background blur for depth
/// - Optional gradient and stroke for enhanced depth
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double opacity;
  final double blur;
  final Color? color;
  final Gradient? gradient;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.opacity = 0.2,
    this.blur = 20.0,
    this.color,
    this.gradient,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Default color based on theme
    final defaultColor = color ?? 
        (isDark 
        ? Colors.white.withValues(alpha: opacity)
        : Colors.white.withValues(alpha: opacity));
    
    // Default gradient for depth
    final defaultGradient = gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            defaultColor,
            defaultColor.withValues(alpha: opacity * 0.5),
          ],
        );

    // Default border for depth
    final defaultBorder = border ??
        Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        );

    // Default shadow
    final defaultShadow = boxShadow ??
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ];

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: defaultShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: defaultGradient,
              borderRadius: borderRadius ?? BorderRadius.circular(16),
              border: defaultBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

