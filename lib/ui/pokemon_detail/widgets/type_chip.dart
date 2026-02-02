import 'package:flutter/material.dart';
import '../../../app/theme/type_colors.dart';
import 'type_icon.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: typeColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TypeIcon(
            type: type,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            type,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
