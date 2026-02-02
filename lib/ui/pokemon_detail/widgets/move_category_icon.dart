import 'package:flutter/material.dart';

class MoveCategoryIcon extends StatelessWidget {
  final String category;

  const MoveCategoryIcon({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    String displayCategory = category.toLowerCase();
    if (displayCategory == 'dependent') {
      displayCategory = 'both';
    }
    return Image.asset(
      'assets/icons/png/attack/$displayCategory.png',
      errorBuilder: (context, error, stackTrace) {
        // Fallback to icon if image fails to load
        return Icon(Icons.category);
      },
    );
  }
}
