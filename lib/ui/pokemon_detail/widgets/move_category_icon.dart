import 'package:flutter/material.dart';

class MoveCategoryIcon extends StatelessWidget {
  final String category;

  const MoveCategoryIcon({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/png/attack/$category.png',
      errorBuilder: (context, error, stackTrace) {
        // Fallback to icon if image fails to load
        return Icon(Icons.category);
      },
    );
  }
}
