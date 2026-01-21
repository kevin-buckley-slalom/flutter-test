import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/pokemon.dart';
import 'pokemon_list_view_model.dart';
import 'widgets/pokemon_list_item.dart';
import '../pokemon_detail/pokemon_detail_view.dart';

class PokemonListView extends ConsumerStatefulWidget {
  const PokemonListView({super.key});

  @override
  ConsumerState<PokemonListView> createState() => _PokemonListViewState();
}

class _PokemonListViewState extends ConsumerState<PokemonListView> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  String _sortField = 'number'; // 'number', 'name', 'bst', 'hp', 'attack', 'defense', 'spAtk', 'spDef', 'speed'
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Pokemon pokemon, String query) {
    if (query.isEmpty) return true;

    // Check name
    if (pokemon.baseName.toLowerCase().contains(query)) {
      return true;
    }

    // Check variant
    if (pokemon.variant != null &&
        pokemon.variant!.toLowerCase().contains(query)) {
      return true;
    }

    // Check types
    if (pokemon.types.any((type) => type.toLowerCase().contains(query))) {
      return true;
    }

    return false;
  }

  List<Pokemon> _sortList(List<Pokemon> list) {
    final sortedList = List<Pokemon>.from(list);

    sortedList.sort((a, b) {
      int comparison = 0;

      switch (_sortField) {
        case 'number':
          comparison = a.number.compareTo(b.number);
          break;
        case 'name':
          comparison = a.baseName.compareTo(b.baseName);
          break;
        case 'bst':
          comparison = a.stats.total.compareTo(b.stats.total);
          break;
        case 'hp':
          comparison = a.stats.hp.compareTo(b.stats.hp);
          break;
        case 'attack':
          comparison = a.stats.attack.compareTo(b.stats.attack);
          break;
        case 'defense':
          comparison = a.stats.defense.compareTo(b.stats.defense);
          break;
        case 'spAtk':
          comparison = a.stats.spAtk.compareTo(b.stats.spAtk);
          break;
        case 'spDef':
          comparison = a.stats.spDef.compareTo(b.stats.spDef);
          break;
        case 'speed':
          comparison = a.stats.speed.compareTo(b.stats.speed);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sortedList;
  }

  void _showSortOptions(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sort By',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sortAscending ? 'Asc' : 'Desc',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _sortAscending ? 0 : 0.5,
                        duration: const Duration(milliseconds: 300),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_upward,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () {
                            setState(() {
                              _sortAscending = !_sortAscending;
                            });
                            setModalState(() {});
                          },
                          tooltip: _sortAscending
                              ? 'Switch to descending'
                              : 'Switch to ascending',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Sort options list
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...[
                      ('number', 'Pokédex Number'),
                      ('name', 'Name'),
                      ('bst', 'Base Stat Total'),
                      ('hp', 'HP'),
                      ('attack', 'Attack'),
                      ('defense', 'Defense'),
                      ('spAtk', 'Sp. Attack'),
                      ('spDef', 'Sp. Defense'),
                      ('speed', 'Speed'),
                    ].map((option) {
                      final (field, label) = option;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _sortField = field;
                            });
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: _sortField == field
                                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Text(
                                label,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: _sortField == field
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                  fontWeight: _sortField == field
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pokemonAsync = ref.watch(pokemonListViewModelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Champion Dex',
          style: GoogleFonts.racingSansOne(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.sort,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () => _showSortOptions(context),
            tooltip: 'Sort and filter',
          ),
        ],
      ),
      body: pokemonAsync.when(
        data: (pokemonList) {
          // Filter the list based on search query
          final filteredList = _searchQuery.isEmpty
              ? pokemonList
              : pokemonList
                  .where((pokemon) => _matchesSearch(pokemon, _searchQuery))
                  .toList();

          // Sort the filtered list
          final sortedList = _sortList(filteredList);

          return Column(
            children: [
              // Search bar
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, variant, or type...',
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
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                ),
              ),

              // List content
              Expanded(
                child: sortedList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No Pokemon found'
                                : 'No Pokemon match "$_searchQuery"',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: sortedList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final pokemon = sortedList[index];
                          return PokemonListItem(
                            pokemon: pokemon,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PokemonDetailView(
                                    pokemon: pokemon,
                                  ),
                                ),
                              );
                            },
                            statField: ['hp', 'attack', 'defense', 'spAtk', 'spDef', 'speed', 'bst'].contains(_sortField) ? _sortField : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading Pokemon data',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




