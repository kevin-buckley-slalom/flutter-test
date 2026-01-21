import 'package:flutter/material.dart';
import '../../../domain/utils/stat_formatter.dart';

class StatBarChart extends StatelessWidget {
  final String statName;
  final int value;
  final int maxValue;
  final bool isTotal;

  const StatBarChart({
    super.key,
    required this.statName,
    required this.value,
    this.maxValue = 200,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = StatFormatter.formatStatName(statName);

    // For BST total, display differently
    if (isTotal) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                "Total",
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 2
              ),
            ),
            Text(
              value.toString(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    Color barColor;
    if (value >= 200) {
      barColor = Colors.cyan;
    } else if (value >= 120) {
      barColor = Colors.green;
    } else if (value >= 90) {
      barColor = Colors.lightGreen;
    } else if (value >= 60) {
      barColor = Colors.yellow;
    } else if (value >= 30) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              displayName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (value / maxValue).clamp(0.0, 1.0),
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 35,
            child: Text(
              value.toString(),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}




