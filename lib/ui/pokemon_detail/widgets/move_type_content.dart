import 'package:championdex/ui/pokemon_detail/widgets/move_category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:championdex/data/models/move.dart';

final Map<String, String> moveTypeDisplayNames = {
  'level_up': 'Moves Learned by Level Up',
  'tm': 'TM Moves',
  'hm': 'HM Moves',
  'tr': 'TR Moves',
  'egg_moves': 'Egg Moves',
  'tutor': 'Learned by Move Tutor',
  'tutor_attacks': 'Learned by Move Tutor',
  'transfer': 'Transfer Only Moves',
};

class MoveTypeContent extends ConsumerWidget {
  final String moveType;
  final List<PokemonMove> moves;
  final FutureProvider<Move?> Function(String) moveDetailsProvider;

  const MoveTypeContent({
    super.key,
    required this.moveType,
    required this.moves,
    required this.moveDetailsProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '${moveTypeDisplayNames[moveType]}:',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...moves.map((move) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MoveListItem(
              move: move,
              moveDetailsProvider: moveDetailsProvider,
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MoveListItem extends ConsumerWidget {
  final PokemonMove move;
  final FutureProvider<Move?> Function(String) moveDetailsProvider;

  const _MoveListItem({
    required this.move,
    required this.moveDetailsProvider,
  });

  Color _getCategoryColor(BuildContext context, String category) {
    switch (category) {
      case 'Physical':
        return Colors.orange;
      case 'Special':
        return Colors.blue;
      case 'Status':
        return Colors.grey;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  Color _getLearnTypeColor(BuildContext context, String type) {
    final theme = Theme.of(context);
    switch (type) {
      case 'level_up':
        return Colors.green;
      case 'tm':
      case 'hm':
      case 'tr':
        return Colors.blue;
      case 'egg':
        return Colors.orange;
      case 'tutor':
        return Colors.purple;
      case 'transfer':
        return Colors.red;
      default:
        return theme.colorScheme.outline;
    }
  }

  String _formatLearnMethod() {
    if (move.level != '—') {
      return move.level;
    }
    if (move.tmId != null) {
      return move.tmId!;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ref.watch(moveDetailsProvider(move.name)).when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (moveData) {
        if (moveData == null) return const SizedBox.shrink();

        final learnColor = _getLearnTypeColor(context, move.learnType);
        final learnMethodText = _formatLearnMethod();
        final dividerColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
        final dividerColorLight = theme.colorScheme.onSurface.withValues(alpha: 0.2);

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left section: Icon, name, and stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Category icon + Move name
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Fixed width for category icon
                            SizedBox(
                              width: 50,
                              child: Tooltip(
                                message: moveData.category,
                                child: MoveCategoryIcon(category: moveData.category.toLowerCase()),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
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
                                      moveData.power?.toString() ?? '—',
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
                                      moveData.accuracy?.toString() ?? '—',
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
                                      '${moveData.pp} - ${(moveData.pp * 1.6).toStringAsFixed(0)}',
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
                // Right section: Learn method badge
                Container(
                  margin: const EdgeInsetsDirectional.symmetric(horizontal: 0, vertical: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: learnColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: learnColor.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        learnMethodText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: learnColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
