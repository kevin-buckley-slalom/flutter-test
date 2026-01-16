import 'package:flutter/material.dart';
import '../../../app/theme/type_colors.dart';
import '../../../data/models/type_effectiveness.dart';

class TypeEffectivenessCompact extends StatelessWidget {
  final Map<String, Effectiveness>? defensiveEffectiveness;
  final Map<String, Effectiveness>? offensiveEffectiveness;

  const TypeEffectivenessCompact({
    super.key,
    this.defensiveEffectiveness,
    this.offensiveEffectiveness,
  });

  String _abbreviateType(String type) {
    return type.substring(0, 3).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivenessMap =
        defensiveEffectiveness ?? offensiveEffectiveness ?? {};

    if (effectivenessMap.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort types alphabetically - include all types
    final sortedTypes = effectivenessMap.keys.toList()..sort();

    if (sortedTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate items per row to ensure maximum 2 rows
    final itemsPerRow = (sortedTypes.length / 2).ceil();

    // Split into two rows
    final firstRow = sortedTypes.take(itemsPerRow).toList();
    final secondRow = sortedTypes.skip(itemsPerRow).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (firstRow.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: firstRow.map((type) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.5),
                child: _buildTypeItem(theme, type, effectivenessMap[type]!),
              ),
            )).toList(),
          ),
        if (secondRow.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: secondRow.map((type) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.5),
                child: _buildTypeItem(theme, type, effectivenessMap[type]!),
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTypeItem(ThemeData theme, String type, Effectiveness effectiveness) {
    final typeColor = TypeColors.getColor(type);
    final textColor = TypeColors.getTextColor(type);

    // Determine multiplier display
    String multiplier;
    Color overlayColor;
    double overlayFontSize = 12;

    if (effectiveness == Effectiveness.immune) {
      multiplier = '0';
      overlayColor = Colors.grey.shade700;
    } else if (effectiveness == Effectiveness.hardlyEffective) {
      multiplier = '¼';
      overlayColor = Colors.green.shade700;
      overlayFontSize = 18;
    } else if (effectiveness == Effectiveness.notVeryEffective) {
      multiplier = '½';
      overlayColor = Colors.lightGreen;
      overlayFontSize = 18;
    } else if (effectiveness == Effectiveness.normal) {
      // Empty multiplier for neutral effectiveness
      multiplier = '';
      overlayColor = Colors.transparent;
    } else if (effectiveness == Effectiveness.superEffective) {
      multiplier = '2';
      overlayColor = Colors.red.shade400;
    } else if (effectiveness == Effectiveness.extremelyEffective) {
      multiplier = '4';
      overlayColor = Colors.red.shade900;
    } else {
      multiplier = '1';
      overlayColor = Colors.transparent;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.2),
              ),
            ),
            child: Center(
              child: Text(
                _abbreviateType(type),
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: overlayColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.2),
              ),
            ),
            child: Center(
              child: Text(
                multiplier,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: overlayFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
