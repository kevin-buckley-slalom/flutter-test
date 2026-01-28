import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/pokemon.dart';
import '../../../ui/pokemon_list/pokemon_list_view_model.dart';
import '../../shared/pokemon_image.dart';

class PokemonSelectorSheet extends ConsumerStatefulWidget {
  final Function(Pokemon) onPokemonSelected;

  const PokemonSelectorSheet({
    super.key,
    required this.onPokemonSelected,
  });

  @override
  ConsumerState<PokemonSelectorSheet> createState() =>
      _PokemonSelectorSheetState();
}

class _PokemonSelectorSheetState extends ConsumerState<PokemonSelectorSheet> {
  late TextEditingController _searchController;
  String _searchQuery = '';

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

    if (pokemon.baseName.toLowerCase().contains(query)) {
      return true;
    }

    if (pokemon.variant != null &&
        pokemon.variant!.toLowerCase().contains(query)) {
      return true;
    }

    for (final type in pokemon.types) {
      if (type.toLowerCase().contains(query)) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pokemonAsync = ref.watch(pokemonListViewModelProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Pokémon',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Pokémon...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
          ),

          // Pokemon list
          Expanded(
            child: pokemonAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error loading Pokémon: $error'),
              ),
              data: (pokemonList) {
                final filteredList = pokemonList
                    .where((p) => _matchesSearch(p, _searchQuery))
                    .toList();

                return ListView.builder(
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final pokemon = filteredList[index];
                    return ListTile(
                      leading: PokemonImage(
                        imagePath: pokemon.imagePath,
                        imagePathLarge: pokemon.imagePathLarge,
                        size: 48,
                        useLarge: false,
                      ),
                      title: Text(pokemon.baseName),
                      subtitle: pokemon.variant != null
                          ? Text(pokemon.variant!)
                          : null,
                      trailing: Text(
                        '#${pokemon.number.toString().padLeft(3, '0')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        widget.onPokemonSelected(pokemon);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
