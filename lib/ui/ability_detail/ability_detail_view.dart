import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ability.dart';
import '../../data/services/ability_data_service.dart';
import '../pokemon_detail/pokemon_detail_view.dart';
import '../pokemon_list/pokemon_list_view_model.dart';
import '../shared/flat_card.dart';

final abilityByNameProvider = FutureProvider.family<Ability?, String>((ref, abilityName) async {
  final abilityService = AbilityDataService();
  await abilityService.loadData();
  return abilityService.getAbilityByName(abilityName);
});

class AbilityDetailView extends ConsumerWidget {
  final String abilityName;

  const AbilityDetailView({
    super.key,
    required this.abilityName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abilityAsync = ref.watch(abilityByNameProvider(abilityName));

    return abilityAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Ability Details'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Ability Details'),
        ),
        body: Center(
          child: Text('Error loading ability: $error'),
        ),
      ),
      data: (ability) {
        if (ability == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('Ability Details'),
            ),
            body: const Center(
              child: Text('Ability not found'),
            ),
          );
        }

        return _AbilityDetailContent(
          ability: ability,
          onPokemonTap: (pokemonName) async {
            // Look up pokemon and navigate
            final pokemonRepository = ref.read(pokemonRepositoryProvider);
            await pokemonRepository.initialize();
            final pokemon = pokemonRepository.byName(pokemonName);
            if (pokemon != null && context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PokemonDetailView(pokemon: pokemon),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _AbilityDetailContent extends StatelessWidget {
  final Ability ability;
  final Function(String) onPokemonTap;

  const _AbilityDetailContent({
    required this.ability,
    required this.onPokemonTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final regularPokemonList = ability.regularPokemon.toList()..sort();
    final hiddenPokemonList = ability.hiddenPokemon.toList()..sort();
    final hasAnyPokemon = regularPokemonList.isNotEmpty || hiddenPokemonList.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Ability Details'),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ability Title
              Text(
                ability.name,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Effect Description
              FlatCard(
                padding: const EdgeInsets.all(16),
                elevation: 1,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Effect',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ability.effect.isEmpty ? 'No description available' : ability.effect,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              if (!hasAnyPokemon)
                FlatCard(
                  padding: const EdgeInsets.all(16),
                  elevation: 1,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Text(
                      'No Pokémon found with this ability',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                )
              else ...[
                // Regular Ability Pokemon
                if (regularPokemonList.isNotEmpty) ...[
                  Text(
                    'Pokémon with this Ability',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: regularPokemonList.length,
                    itemBuilder: (context, index) {
                      final pokemonName = regularPokemonList[index];
                      return _PokemonAbilityRow(
                        pokemonName: pokemonName,
                        isRegular: true,
                        isHidden: false,
                        onTap: () => onPokemonTap(pokemonName),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],

                // Hidden Ability Pokemon
                if (hiddenPokemonList.isNotEmpty) ...[
                  Text(
                    'Pokémon with this as Hidden Ability',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: hiddenPokemonList.length,
                    itemBuilder: (context, index) {
                      final pokemonName = hiddenPokemonList[index];
                      return _PokemonAbilityRow(
                        pokemonName: pokemonName,
                        isRegular: false,
                        isHidden: true,
                        onTap: () => onPokemonTap(pokemonName),
                      );
                    },
                  ),
                ],
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PokemonAbilityRow extends StatefulWidget {
  final String pokemonName;
  final bool isRegular;
  final bool isHidden;
  final VoidCallback onTap;

  const _PokemonAbilityRow({
    required this.pokemonName,
    required this.isRegular,
    required this.isHidden,
    required this.onTap,
  });

  @override
  State<_PokemonAbilityRow> createState() => _PokemonAbilityRowState();
}

class _PokemonAbilityRowState extends State<_PokemonAbilityRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (hovering) {
            setState(() {
              _isHovered = hovering;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isHovered
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                width: _isHovered ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Pokemon image placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // Pokemon name and ability type indicators
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.pokemonName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (widget.isRegular) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Regular',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (widget.isRegular && widget.isHidden)
                            const SizedBox(width: 8),
                          if (widget.isHidden) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Hidden',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Chevron
                Icon(
                  Icons.chevron_right,
                  color: _isHovered
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
