import 'package:championdex/ui/shared/pokemon_image.dart';
import 'package:flutter/material.dart';
import '../../data/models/pokemon.dart';
import '../shared/flat_card.dart';
import '../shared/parallax_scroll_container.dart';
import 'pokemon_detail_view_model.dart';
import 'widgets/stat_bar_chart.dart';
import 'widgets/type_chip.dart';
import 'widgets/type_effectiveness_tabs.dart';

class PokemonDetailView extends StatelessWidget {
  final Pokemon pokemon;

  const PokemonDetailView({
    super.key,
    required this.pokemon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = PokemonDetailViewModel.fromPokemon(pokemon);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(pokemon.baseName),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ParallaxScrollContainer(
        backgroundHeight: 280,
        contentBackgroundColor: theme.colorScheme.surface,
        contentBorderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        backgroundChild: Stack(
          children: [
            // Background gradient for hero area
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
              ),
            ),
            // Hero image centered in background
            Center(
              child: Hero(
                tag: 'pokemon-image-${pokemon.number}-${pokemon.variant ?? 'base'}',
                child: PokemonImage(imagePath: pokemon.imagePath, imagePathLarge: pokemon.imagePathLarge, size: 200, useLarge: true),
              ),
            ),
          ],
        ),
        contentChild: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pokemon number badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '#${pokemon.number.toString().padLeft(3, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Variant badge
              if (pokemon.variant != null) ...[
                FlatCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  backgroundColor:
                      theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  elevation: 0,
                  child: Text(
                    pokemon.variant!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Generation
              const SizedBox(height: 12),
              Text(
                'Generation ${pokemon.generation}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),

              // Types
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pokemon.types
                    .map((type) => TypeChip(type: type))
                    .toList(),
              ),

              // Base Stats
              const SizedBox(height: 32),
              Text(
                'Base Stats',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FlatCard(
                padding: const EdgeInsets.all(16),
                elevation: 1,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    StatBarChart(
                      statName: 'hp',
                      value: pokemon.stats.hp,
                    ),
                    StatBarChart(
                      statName: 'attack',
                      value: pokemon.stats.attack,
                    ),
                    StatBarChart(
                      statName: 'defense',
                      value: pokemon.stats.defense,
                    ),
                    StatBarChart(
                      statName: 'sp_atk',
                      value: pokemon.stats.spAtk,
                    ),
                    StatBarChart(
                      statName: 'sp_def',
                      value: pokemon.stats.spDef,
                    ),
                    StatBarChart(
                      statName: 'speed',
                      value: pokemon.stats.speed,
                    ),
                    StatBarChart(
                      statName: 'BST',
                      value: pokemon.stats.total,
                      isTotal: true,
                    ),
                  ],
                ),
              ),

              // Type Effectiveness
              const SizedBox(height: 28),
              Text(
                'Type Effectiveness',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FlatCard(
                padding: const EdgeInsets.all(16),
                elevation: 1,
                borderRadius: BorderRadius.circular(16),
                child: TypeEffectivenessTabs(
                  pokemon: pokemon,
                  defensiveTypeEffectiveness: viewModel.defensiveTypeEffectiveness,
                  offensiveTypeEffectiveness: viewModel.offensiveTypeEffectiveness,
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}