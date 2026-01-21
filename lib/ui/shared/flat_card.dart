import 'package:flutter/material.dart';

/// A flat design card widget with clean lines and subtle elevation.
/// 
/// This widget implements a modern flat design approach with:
/// - Clean, minimal borders
/// - Subtle shadows for depth
/// - No glassmorphic effects
/// - Clear hierarchy and focus on content
class FlatCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final double elevation;
  final VoidCallback? onTap;

  const FlatCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.border,
    this.elevation = 1.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Default colors based on theme
    final defaultBackgroundColor = backgroundColor ??
        (isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white);
    
    final defaultBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.0,
        );

    final defaultRadius = borderRadius ?? BorderRadius.circular(12);

    final child_ = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: defaultBackgroundColor,
        borderRadius: defaultRadius,
        border: defaultBorder,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation * 0.5),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: defaultRadius,
          child: child_,
        ),
      );
    }

    return child_;
  }
}
