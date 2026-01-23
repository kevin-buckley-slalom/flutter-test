import 'package:flutter/material.dart';
import '../../../app/theme/type_colors.dart';

class TypeChip extends StatelessWidget {
  final String type;
  final double? fontSize;

  const TypeChip({
    super.key,
    required this.type,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = TypeColors.getColor(type);
    final textColor = TypeColors.getTextColor(type);

    return SizedBox(
      width: 85, // Fixed width for consistent size
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: typeColor,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          type,
          textAlign: TextAlign.center, // Center the text
          style: TextStyle(
            color: textColor,
            fontSize: fontSize ?? 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}




