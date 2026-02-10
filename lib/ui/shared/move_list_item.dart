import 'package:flutter/material.dart';
import '../../data/models/move.dart';
import '../pokemon_detail/widgets/move_category_icon.dart';
import '../pokemon_detail/widgets/type_icon.dart';

class MoveListItem extends StatelessWidget {
  final Move move;
  final VoidCallback onTap;

  const MoveListItem({
    super.key,
    required this.move,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor =
        theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
    final dividerColorLight =
        theme.colorScheme.onSurface.withValues(alpha: 0.2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Type icon + Move name + Category icon
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Type icon
                    Tooltip(
                      message: move.type,
                      child: TypeIcon(
                        type: move.type,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Move name - emphasized and bold
                    Expanded(
                      child: Text(
                        move.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Fixed width for category icon
                    SizedBox(
                      width: 50,
                      child: Tooltip(
                        message: move.category,
                        child: MoveCategoryIcon(
                          category: move.category.toLowerCase(),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              // Divider between name and stats
              Divider(
                height: 1,
                color: dividerColor,
                thickness: 1,
                indent: 8,
                endIndent: 8,
              ),
              // Stats table: Power, Accuracy, PP
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Power column
                    Expanded(
                      flex: 5,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Power',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              move.power?.toString() ?? '—',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Vertical divider
                    Container(
                      width: 1,
                      height: 45,
                      color: dividerColorLight,
                    ),
                    // Accuracy column
                    Expanded(
                      flex: 6,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Accuracy',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              move.accuracy?.toString() ?? '—',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Vertical divider
                    Container(
                      width: 1,
                      height: 45,
                      color: dividerColorLight,
                    ),
                    // PP column
                    Expanded(
                      flex: 5,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'PP',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${move.pp} - ${(move.pp * 1.6).toStringAsFixed(0)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
