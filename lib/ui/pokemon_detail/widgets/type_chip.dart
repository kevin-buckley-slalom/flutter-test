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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: typeColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize ?? 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}




