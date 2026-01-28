import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/pokemon.dart';
import '../../../data/models/move.dart';
import '../../../data/services/pokemon_move_data_service.dart';
import '../../moves_list/moves_list_view_model.dart';
import '../../pokemon_detail/widgets/move_category_icon.dart';

class MovesSelectorSheet extends ConsumerStatefulWidget {
  final Pokemon pokemon;
  final Function(String) onMoveSelected;

  const MovesSelectorSheet({
    super.key,
    required this.pokemon,
    required this.onMoveSelected,
  });

  @override
  ConsumerState<MovesSelectorSheet> createState() => _MovesSelectorSheetState();
}

class _MovesSelectorSheetState extends ConsumerState<MovesSelectorSheet> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  List<Move> _availableMoves = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadAvailableMoves();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableMoves() async {
    final moveService = PokemonMoveDataService();
    final moveNames = await moveService.getAvailableMovesForPokemon(
      widget.pokemon.baseName,
      widget.pokemon.name,
    );

    // Load the full Move objects from the moves list
    final allMoves = await ref.read(movesListViewModelProvider.future);
    final movesMap = {for (var move in allMoves) move.name: move};

    if (mounted) {
      setState(() {
        _availableMoves = moveNames
            .map((name) => movesMap[name])
            .whereType<Move>()
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      });
    }
  }

  bool _matchesSearch(Move move, String query) {
    return move.name.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredMoves = _availableMoves
        .where((move) => _matchesSearch(move, _searchQuery))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Header with title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select a Move',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search moves...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.primary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Moves list
            Expanded(
              child: _availableMoves.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No moves available for this Pokémon',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : filteredMoves.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No moves match "$_searchQuery"',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : Scrollbar(
                          thickness: 16,
                          radius: const Radius.circular(8),
                          child: ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: filteredMoves.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final move = filteredMoves[index];
                              return _MoveListItem(
                                move: move,
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onMoveSelected(move.name);
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveListItem extends StatelessWidget {
  final Move move;
  final VoidCallback onTap;

  const _MoveListItem({
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
              // Top row: Category icon + Move name
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Fixed width for category icon
                    SizedBox(
                      width: 50,
                      child: Tooltip(
                        message: move.category,
                        child: MoveCategoryIcon(
                          category: move.category.toLowerCase(),
                        ),
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
