import 'package:championdex/ui/pokemon_detail/widgets/move_category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/move.dart';
import '../../data/models/pokemon.dart';
import '../../data/services/move_data_service.dart';
import '../../data/services/pokemon_move_data_service.dart';
import '../pokemon_detail/pokemon_detail_view.dart';
import '../pokemon_list/pokemon_list_view_model.dart';
import '../shared/flat_card.dart';
import '../shared/pokemon_image.dart';
import '../pokemon_detail/widgets/type_chip.dart';
import '../pokemon_detail/widgets/move_type_tabs.dart';

final moveByNameProvider =
    FutureProvider.family<Move?, String>((ref, moveName) async {
  final moveService = MoveDataService();
  await moveService.loadData();
  return moveService.getMoveByName(moveName);
});

final moveAvailableGamesProvider =
    FutureProvider.family<Map<String, List<String>>, String>(
        (ref, moveName) async {
  final pokemonMoveService = PokemonMoveDataService();
  return await pokemonMoveService.getAvailableGamesForMove(moveName);
});

String cleanPokemonName(String raw) {
  final parts = raw.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return raw;
  if (parts.length >= 3 && parts.first == parts.last) {
    final base = parts.first;
    final variant = parts.sublist(1, parts.length - 1).join(' ');
    if (variant.toLowerCase().contains(base.toLowerCase())) return variant;
    return '$base $variant';
  }
  final base = parts.last;
  final variant = parts.sublist(0, parts.length - 1).join(' ');
  if (variant.toLowerCase().contains(base.toLowerCase())) return variant;
  return '$base $variant';
}

String formatPokemonDisplay(Pokemon? pokemon, String rawName) {
  if (pokemon != null) {
    final base = pokemon.baseName;
    final variant = pokemon.variant;
    if (variant != null && variant.isNotEmpty) {
      if (variant.toLowerCase().contains(base.toLowerCase())) return variant;
      return '$base $variant';
    }
    return pokemon.name;
  }
  return cleanPokemonName(rawName);
}

final pokemonLearningMoveProvider =
    FutureProvider.family<Map<String, List<PokemonMove>>, Map<String, String?>>(
        (ref, params) async {
  final pokemonMoveService = PokemonMoveDataService();
  final moveName = params['move']!;
  final game = params['game'];
  final method = params['method'];
  return await pokemonMoveService.getPokemonLearningMoveFiltered(moveName,
      game: game, method: method);
});

class MoveDetailView extends ConsumerWidget {
  final String moveName;

  const MoveDetailView({
    super.key,
    required this.moveName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moveAsync = ref.watch(moveByNameProvider(moveName));

    return moveAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Move Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Move Details'),
        ),
        body: Center(child: Text('Error loading move: $error')),
      ),
      data: (move) {
        if (move == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('Move Details'),
            ),
            body: const Center(child: Text('Move not found')),
          );
        }

        return _MoveDetailContent(
          move: move,
          pokemonRepository: ref.read(pokemonRepositoryProvider),
          onPokemonTap: (pokemonName) =>
              _navigateToPokemon(context, ref, pokemonName),
        );
      },
    );
  }

  Future<void> _navigateToPokemon(
      BuildContext context, WidgetRef ref, String pokemonName) async {
    final pokemonRepository = ref.read(pokemonRepositoryProvider);
    await pokemonRepository.initialize();
    final pokemon = pokemonRepository.byName(pokemonName);
    if (pokemon != null && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => PokemonDetailView(pokemon: pokemon)));
    }
  }
}

class _MoveDetailContent extends ConsumerStatefulWidget {
  final Move move;
  final Function(String) onPokemonTap;
  final dynamic pokemonRepository;

  const _MoveDetailContent({
    required this.move,
    required this.onPokemonTap,
    required this.pokemonRepository,
  });

  @override
  ConsumerState<_MoveDetailContent> createState() => _MoveDetailContentState();
}

class _MoveDetailContentState extends ConsumerState<_MoveDetailContent> {
  bool _isInitialized = false;
  String _selectedGame = '';
  String _selectedMoveType = 'level_up';

  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }

  Future<void> _initializeRepository() async {
    await widget.pokemonRepository.initialize();
    if (mounted) setState(() => _isInitialized = true);
  }

  Pokemon? _getPokemon(String pokemonName) {
    if (!_isInitialized) return null;
    var pokemon = widget.pokemonRepository.byName(pokemonName);
    if (pokemon != null) return pokemon;
    final allPokemon = widget.pokemonRepository.all();
    pokemon = allPokemon.cast<Pokemon?>().firstWhere(
        (p) => p?.variant?.toLowerCase() == pokemonName.toLowerCase(),
        orElse: () => null);
    if (pokemon != null) return pokemon;
    final byBaseName = widget.pokemonRepository.byBaseName(pokemonName);
    if (byBaseName.isNotEmpty) return byBaseName.first;
    return null;
  }

  List<MapEntry<String, List<PokemonMove>>> _getFilteredPokemon(
      Map<String, List<PokemonMove>> data) {
    return data.entries
        .where((entry) =>
            entry.value.any((move) => move.learnType == _selectedMoveType))
        .map((entry) => MapEntry(
            entry.key,
            entry.value
                .where((move) => move.learnType == _selectedMoveType)
                .toList()))
        .where((entry) => entry.value.isNotEmpty)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableGamesAsync =
        ref.watch(moveAvailableGamesProvider(widget.move.name));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop()),
        title: const Text('Move Details'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.move.name,
                style: theme.textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FlatCard(
              padding: const EdgeInsets.all(16),
              elevation: 1,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Effect',
                    style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(
                    // Prefer detailed_effect when available, fall back to brief effect
                    ((widget.move.detailedEffect != null && widget.move.detailedEffect!.isNotEmpty)
                      ? widget.move.detailedEffect!
                      : (widget.move.effect.isEmpty
                        ? 'No description available'
                        : widget.move.effect)),
                    style: theme.textTheme.bodyMedium
                      ?.copyWith(height: 1.6)),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            FlatCard(
              padding: const EdgeInsets.all(16),
              elevation: 1,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Move Details',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    _MoveStatsTable(move: widget.move),
                  ]),
            ),
            const SizedBox(height: 24),
            if (widget.move.targets != null)
              SizedBox(
                width: double.infinity,
                child: FlatCard(
                  padding: const EdgeInsets.all(16),
                  elevation: 1,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Targets',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Text(widget.move.targets ?? 'Unknown',
                            style:
                                theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                      ]),
                ),
              ),

            const SizedBox(height: 32),
            Text('Pokémon that learn ${widget.move.name}',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Available games and move methods
            availableGamesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Error loading move game data: $e'),
              data: (gameMap) {
                final games = gameMap.keys.toList();
                if (games.isEmpty)
                  return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No game data available for this move'));

                final sortedGames = <String>[];
                final order = [
                  'Legends: Z-A',
                  'Scarlet and Violet',
                  'Sword and Shield',
                  'Legends Arceus',
                  'Brilliant Diamond and Shining Pearl'
                ];
                for (final g in order)
                  if (games.contains(g)) sortedGames.add(g);
                for (final g in games)
                  if (!sortedGames.contains(g)) sortedGames.add(g);

                if (_selectedGame.isEmpty ||
                    !sortedGames.contains(_selectedGame))
                  _selectedGame = sortedGames.first;
                final availableMethods = gameMap[_selectedGame] ?? [];
                if (availableMethods.isNotEmpty &&
                    !availableMethods.contains(_selectedMoveType))
                  _selectedMoveType = availableMethods.first;

                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Game',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: _selectedGame,
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedGame = v);
                        },
                        items: sortedGames
                            .map((g) =>
                                DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        isExpanded: true,
                      ),
                      const SizedBox(height: 12),
                      MoveTypeTabs(
                          availableTypes: availableMethods,
                          selectedMoveType: _selectedMoveType,
                          onMoveTypeChanged: (t) =>
                              setState(() => _selectedMoveType = t)),
                      const SizedBox(height: 12),
                      FutureBuilder<Map<String, List<PokemonMove>>>(
                        future: PokemonMoveDataService()
                            .getPokemonLearningMoveFiltered(widget.move.name,
                                game: _selectedGame, method: _selectedMoveType),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            return const Center(
                                child: CircularProgressIndicator());
                          final data = snapshot.data ?? {};
                          final filteredPokemon = _getFilteredPokemon(data);
                          if (filteredPokemon.isEmpty)
                            return FlatCard(
                                padding: const EdgeInsets.all(16),
                                elevation: 1,
                                borderRadius: BorderRadius.circular(16),
                                child: Center(
                                    child: Text(
                                        'No Pokémon found that learn this move',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withValues(alpha: 0.6)))));

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredPokemon.length,
                            itemBuilder: (context, index) {
                              final entry = filteredPokemon[index];
                              final pokemonName = entry.key;
                              final moves = entry.value;
                              final pokemon = _getPokemon(pokemonName);

                              return _PokemonMoveRow(
                                  pokemonName: pokemonName,
                                  pokemon: pokemon,
                                  moves: moves,
                                  onTap: () =>
                                      widget.onPokemonTap(pokemonName));
                            },
                          );
                        },
                      ),
                    ]);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _MoveStatsTable extends StatelessWidget {
  final Move move;
  const _MoveStatsTable({required this.move});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {0: FlexColumnWidth(6), 1: FlexColumnWidth(7)},
      border: TableBorder(
        verticalInside: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      children: [
        _buildRow(theme, 'Type:', TypeChip(type: move.type)),
        _buildRow(
            theme,
            'Category:',
            SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 50,
                      child: MoveCategoryIcon(
                          category: move.category.toLowerCase()),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      move.category.isNotEmpty
                          ? '${move.category[0].toUpperCase()}${move.category.substring(1)}'
                          : move.category,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            )),
        _buildRow(
            theme,
            'Power:',
            Text(move.power?.toString() ?? '—',
                style: theme.textTheme.bodyLarge)),
        _buildRow(
            theme,
            'Accuracy:',
            Text(move.accuracy?.toString() ?? '—',
                style: theme.textTheme.bodyLarge)),
        _buildRow(
            theme,
            'PP:',
            Text(
                move.maxPp != null
                    ? '${move.pp} / ${move.maxPp}'
                    : move.pp.toString(),
                style: theme.textTheme.bodyLarge)),
        _buildRow(
            theme,
            'Effect Chance:',
            Text(move.effectChance != null ? '${move.effectChance}%' : '—',
                style: theme.textTheme.bodyLarge)),
        _buildRow(
            theme,
            'Makes Contact:',
            Text(move.makesContact ? 'Yes' : 'No',
                style: theme.textTheme.bodyLarge)),
      ],
    );
  }

  TableRow _buildRow(ThemeData theme, String label, Widget value) {
    return TableRow(children: [
        Padding(
          padding:
            const EdgeInsets.symmetric(vertical: 8).copyWith(right: 24),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface
                  .withValues(alpha: 0.7))))),
        Padding(
          padding:
            const EdgeInsets.symmetric(vertical: 8).copyWith(left: 24),
          child: Align(alignment: Alignment.centerLeft, child: value)),
    ]);
  }
}

class _PokemonMoveRow extends StatefulWidget {
  final String pokemonName;
  final Pokemon? pokemon;
  final List<PokemonMove> moves;
  final VoidCallback onTap;

  const _PokemonMoveRow(
      {required this.pokemonName,
      required this.pokemon,
      required this.moves,
      required this.onTap});

  @override
  State<_PokemonMoveRow> createState() => _PokemonMoveRowState();
}

class _PokemonMoveRowState extends State<_PokemonMoveRow> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: FlatCard(
        padding: EdgeInsets.zero,
        elevation: 1,
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (hovering) => setState(() => _isHovered = hovering),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isHovered
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _isHovered
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: _isHovered ? 1.5 : 0),
              ),
              child: Row(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: widget.pokemon != null
                            ? PokemonImage(
                                imagePath: widget.pokemon!.imagePath,
                                imagePathLarge: widget.pokemon!.imagePathLarge,
                                size: 48,
                                useLarge: false)
                            : Icon(Icons.image_not_supported_outlined,
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.5),
                                size: 24))),
                const SizedBox(width: 16),
                Expanded(
                    child: Text(
                        formatPokemonDisplay(
                            widget.pokemon, widget.pokemonName),
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600))),
                const SizedBox(width: 16),
                Icon(Icons.chevron_right,
                    color: _isHovered
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
