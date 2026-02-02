import 'package:championdex/ui/pokemon_detail/widgets/type_icon.dart';
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
            children: firstRow
                .map((type) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.5),
                        child: _buildTypeItem(
                            theme, type, effectivenessMap[type]!),
                      ),
                    ))
                .toList(),
          ),
        if (secondRow.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: secondRow
                .map((type) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.5),
                        child: _buildTypeItem(
                            theme, type, effectivenessMap[type]!),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTypeItem(
      ThemeData theme, String type, Effectiveness effectiveness) {
    final typeColor = TypeColors.getColor(type, alphaValue: 0.3);
    // final textColor = TypeColors.getTextColor(type);

    // Determine multiplier display
    String multiplier;
    Color overlayColor;
    double overlayFontSize = 12;

    if (effectiveness == Effectiveness.immune) {
      multiplier = '0';
      overlayColor = Colors.grey.shade700;
    } else if (effectiveness == Effectiveness.hardlyEffective) {
      multiplier = '¼';
      overlayColor = offensiveEffectiveness == null
          ? Colors.green.shade700
          : Colors.red.shade900;
      overlayFontSize = 18;
    } else if (effectiveness == Effectiveness.notVeryEffective) {
      multiplier = '½';
      overlayColor = offensiveEffectiveness == null
          ? Colors.lightGreen
          : Colors.red.shade400;
      overlayFontSize = 18;
    } else if (effectiveness == Effectiveness.normal) {
      // Empty multiplier for neutral effectiveness
      multiplier = '';
      overlayColor = Colors.transparent;
    } else if (effectiveness == Effectiveness.superEffective) {
      multiplier = '2';
      overlayColor = offensiveEffectiveness == null
          ? Colors.red.shade400
          : Colors.lightGreen;
    } else if (effectiveness == Effectiveness.extremelyEffective) {
      multiplier = '4';
      overlayColor = offensiveEffectiveness == null
          ? Colors.red.shade900
          : Colors.green.shade700;
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
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
                // child: Text(
                //   _abbreviateType(type),
                //   style: TextStyle(
                //     color: textColor,
                //     fontSize: 12,
                //     fontWeight: FontWeight.bold,
                //   ),
                //   textAlign: TextAlign.center,
                // ),
                child: TypeIcon(type: type, size: 32)),
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
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.2),
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
