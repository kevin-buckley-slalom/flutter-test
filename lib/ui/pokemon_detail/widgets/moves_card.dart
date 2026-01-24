import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/data/repositories/move_repository.dart';
import 'package:championdex/ui/pokemon_detail/widgets/move_type_tabs.dart';
import 'package:championdex/ui/pokemon_detail/widgets/move_type_content.dart';

final moveRepositoryProvider = Provider((ref) => MoveRepository());

final availableGenerationsProvider =
    FutureProvider.family<List<String>, String>((ref, baseName) async {
  final repo = ref.watch(moveRepositoryProvider);
  return repo.getAvailableGenerations(baseName);
});

final availableGamesProvider = FutureProvider.family<List<String>,
    ({String baseName, String variant, String generation})>(
  (ref, params) async {
    final repo = ref.watch(moveRepositoryProvider);
    return repo.getAvailableGames(
      params.baseName,
      params.variant,
      params.generation,
    );
  },
);

final pokemonMovesProvider = FutureProvider.family<Map<String, List<PokemonMove>>,
    ({String baseName, String variant, String generation, String game})>(
  (ref, params) async {
    final repo = ref.watch(moveRepositoryProvider);
    await repo.initialize();
    return repo.getMovesForVariant(
      baseName: params.baseName,
      variant: params.variant,
      generation: params.generation,
      game: params.game,
    );
  },
);

final moveDetailsProvider =
    FutureProvider.family<Move?, String>((ref, moveName) async {
  final repo = ref.watch(moveRepositoryProvider);
  await repo.initialize();
  return repo.getMoveByName(moveName);
});

class MovesCard extends ConsumerStatefulWidget {
  final String baseName;
  final String variant;

  const MovesCard({
    super.key,
    required this.baseName,
    required this.variant,
  });

  @override
  ConsumerState<MovesCard> createState() => _MovesCardState();
}

class _MovesCardState extends ConsumerState<MovesCard> {
  late String _selectedGame;
  late String _selectedMoveType;
  late GlobalKey _toggleRowKey;

  @override
  void initState() {
    super.initState();
    _selectedGame = '';
    _selectedMoveType = 'level_up';
    _toggleRowKey = GlobalKey();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ref.watch(availableGenerationsProvider(widget.baseName)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text('Error loading generations: $err'),
          ),
          data: (generations) {
            if (generations.isEmpty) {
              return Text(
                'No move data available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              );
            }

            return _GameSelectorAndMovesContent(
              baseName: widget.baseName,
              variant: widget.variant,
              generations: generations,
              selectedGame: _selectedGame,
              selectedMoveType: _selectedMoveType,
              toggleRowKey: _toggleRowKey,
              onGameChanged: (game) {
                setState(() {
                  _selectedGame = game;
                });
              },
              onMoveTypeChanged: (moveType) {
                setState(() {
                  _selectedMoveType = moveType;
                });
              },
            );
          },
        );
  }
}

class _GameSelectorAndMovesContent extends ConsumerWidget {
  final String baseName;
  final String variant;
  final List<String> generations;
  final String selectedGame;
  final String selectedMoveType;
  final GlobalKey toggleRowKey;
  final Function(String) onGameChanged;
  final Function(String) onMoveTypeChanged;

  const _GameSelectorAndMovesContent({
    required this.baseName,
    required this.variant,
    required this.generations,
    required this.selectedGame,
    required this.selectedMoveType,
    required this.toggleRowKey,
    required this.onGameChanged,
    required this.onMoveTypeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch games from all generations and map to generation
    return FutureBuilder<Map<String, String>>(
      future: _getAllGamesWithGenerations(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final gameToGenerationMap = snapshot.data ?? {};
        if (gameToGenerationMap.isEmpty) {
          return Text(
            'No games available',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }

        // Determine the active game to display
        String activeGame = selectedGame;
        if (activeGame.isEmpty || !gameToGenerationMap.containsKey(activeGame)) {
          // Sort games and pick the first one
          final sortedGames = _getSortedGames(gameToGenerationMap.keys.toList());
          activeGame = sortedGames.first;
          // Trigger callback to update parent state
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onGameChanged(activeGame);
          });
        }

        final generation = gameToGenerationMap[activeGame]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Selector Dropdown
            _GameSelectorDropdown(
              games: gameToGenerationMap.keys.toList(),
              selectedGame: activeGame,
              onGameChanged: onGameChanged,
            ),
            const SizedBox(height: 16),
            // Moves List - always render with active game and move type
            _MovesList(
              baseName: baseName,
              variant: variant,
              generation: generation,
              game: activeGame,
              selectedMoveType: selectedMoveType,
              onMoveTypeChanged: onMoveTypeChanged,
              ref: ref,
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, String>> _getAllGamesWithGenerations(WidgetRef ref) async {
    final repo = ref.read(moveRepositoryProvider);
    final gameToGenerationMap = <String, String>{};

    for (final generation in generations) {
      final games = await repo.getAvailableGames(baseName, variant, generation);
      for (final game in games) {
        gameToGenerationMap[game] = generation;
      }
    }

    return gameToGenerationMap;
  }

  List<String> _getSortedGames(List<String> games) {
    final order = [
      'Legends: Z-A',
      'Scarlet and Violet',
      'Sword and Shield',
      'Legends Arceus',
      'Brilliant Diamond and Shining Pearl',
    ];
    final sorted = <String>[];
    for (final game in order) {
      if (games.contains(game)) {
        sorted.add(game);
      }
    }
    // Add any remaining games not in the predefined order
    for (final game in games) {
      if (!sorted.contains(game)) {
        sorted.add(game);
      }
    }
    return sorted;
  }
}

class _GameSelectorDropdown extends StatelessWidget {
  final List<String> games;
  final String selectedGame;
  final Function(String) onGameChanged;

  const _GameSelectorDropdown({
    required this.games,
    required this.selectedGame,
    required this.onGameChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedGames = _getSortedGames(games);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: selectedGame,
          onChanged: (String? newValue) {
            if (newValue != null) {
              onGameChanged(newValue);
            }
          },
          isExpanded: true,
          items: sortedGames.map<DropdownMenuItem<String>>((String game) {
            return DropdownMenuItem<String>(
              value: game,
              child: Text(game),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<String> _getSortedGames(List<String> games) {
    final order = [
      'Legends: Z-A',
      'Scarlet & Violet',
      'Sword & Shield',
      'Legends Arceus',
      'BDSP',
    ];
    final sorted = <String>[];
    for (final game in order) {
      if (games.contains(game)) {
        sorted.add(game);
      }
    }
    // Add any remaining games not in the predefined order
    for (final game in games) {
      if (!sorted.contains(game)) {
        sorted.add(game);
      }
    }
    return sorted;
  }
}

class _MovesList extends ConsumerWidget {
  final String baseName;
  final String variant;
  final String generation;
  final String game;
  final String selectedMoveType;
  final Function(String) onMoveTypeChanged;
  final WidgetRef ref;

  const _MovesList({
    required this.baseName,
    required this.variant,
    required this.generation,
    required this.game,
    required this.selectedMoveType,
    required this.onMoveTypeChanged,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(pokemonMovesProvider(
          (
            baseName: baseName,
            variant: variant,
            generation: generation,
            game: game,
          ),
        ))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text('Error loading moves: $err'),
          ),
          data: (movesByType) {
            if (movesByType.isEmpty) {
              return Text(
                'No moves available for this game',
                style: Theme.of(context).textTheme.bodyMedium,
              );
            }

            // Filter available move types
            final availableTypes = movesByType.keys.toList();
            final sortedTypes = _getSortedMoveTypes(availableTypes);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Move Type Tabs
                MoveTypeTabs(
                  availableTypes: sortedTypes,
                  selectedMoveType: selectedMoveType,
                  onMoveTypeChanged: onMoveTypeChanged,
                ),
                const SizedBox(height: 16),
                // Moves for selected type
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: (movesByType.containsKey(selectedMoveType) &&
                            (movesByType[selectedMoveType] ?? []).isNotEmpty)
                        ? KeyedSubtree(
                            key: ValueKey('moves_$selectedMoveType'),
                            child: MoveTypeContent(
                              moveType: selectedMoveType,
                              moves: movesByType[selectedMoveType] ?? [],
                              moveDetailsProvider: (name) => moveDetailsProvider(name),
                            ),
                          )
                        : KeyedSubtree(
                            key: ValueKey('empty_$selectedMoveType'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'No moves available for this type',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        );
  }

  List<String> _getSortedMoveTypes(List<String> types) {
    // Include alternate keys sometimes present in data
    final order = [
      'level_up',
      'tm',
      'hm',
      'tr',
      'egg',
      'egg_moves',
      'tutor',
      'tutor_attacks',
      'transfer',
    ];
    types.sort((a, b) {
      final indexA = order.indexOf(a);
      final indexB = order.indexOf(b);
      final aIndex = indexA == -1 ? order.length : indexA;
      final bIndex = indexB == -1 ? order.length : indexB;
      return aIndex.compareTo(bIndex);
    });
    return types;
  }
}
