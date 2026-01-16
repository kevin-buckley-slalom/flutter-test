import 'package:flutter/material.dart';

class TypeIcon extends StatelessWidget {
  final String type;
  final double size;

  const TypeIcon({
    super.key,
    required this.type,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/png/types/color/Pokemon_Type_Icon_$type.png',
      width: size,
      height: size,
      cacheWidth: (size * 2).toInt(),
      cacheHeight: (size * 2).toInt(),
      errorBuilder: (context, error, stackTrace) {
        // Fallback to icon if image fails to load
        return Icon(Icons.category, size: size);
      },
    );
  }
}
