import 'package:championdex/ui/shared/pokemon_image.dart';
import 'package:flutter/material.dart';
import '../../data/models/pokemon.dart';
import '../shared/flat_card.dart';
import '../shared/parallax_scroll_container.dart';
import 'pokemon_detail_view_model.dart';
import 'widgets/moves_card.dart';
import 'widgets/stat_bar_chart.dart';
import 'widgets/type_chip.dart';
import 'widgets/type_effectiveness_tabs.dart';

class PokemonDetailView extends StatelessWidget {
  final Pokemon pokemon;
  late final PokemonDetailViewModel _viewModel;

  PokemonDetailView({
    super.key,
    required this.pokemon,
  }) {
    _viewModel = PokemonDetailViewModel.fromPokemon(pokemon);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
        backgroundHeight: 400,
        contentOffsetTop: 225,
        contentBackgroundColor: Colors.transparent,
        contentBorderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        backgroundChild: Stack(
          children: [
            // Backdrop image
            Positioned.fill(
              child: Image.asset(
                'assets/images/backdrops/${pokemon.backdropPath}',
                fit: BoxFit.cover,
                cacheWidth: 600,
                cacheHeight: 500,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to gradient if backdrop fails to load
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                          theme.colorScheme.secondary.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Semi-transparent overlay for better contrast
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),

          ],
        ),
        contentChild: Stack(
          clipBehavior: Clip.none,
          children: [
              // Card content
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                    width: 2
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                    bottom: Radius.circular(28)
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    stops: theme.brightness == Brightness.dark ? const [0, 0.15, 0.25] : const [0, 0.10, 0.15],
                    colors: [
                      theme.colorScheme.surface.withValues(alpha: 0.5),
                      theme.colorScheme.surface.withValues(alpha: 0.9),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row with spacer for image and name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Spacer for image width
                          const SizedBox(width: 190),
                          // Name and number column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Pokemon base name
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    pokemon.baseName,
                                    style: theme.textTheme.headlineLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Form name (variant)
                                if (pokemon.variant != null) ...[
                                  Text(
                                    pokemon.variant!,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                
                                // Pokemon number
                                Text(
                                  '#${pokemon.number.toString().padLeft(3, '0')}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Types row
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: pokemon.types
                            .map((type) => TypeChip(type: type))
                            .toList(),
                      ),

                      // Abilities
                      const SizedBox(height: 28),
                      Text(
                        'Abilities',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AbilitiesCard(
                        regularAbilities: pokemon.regularAbilities,
                        hiddenAbilities: pokemon.hiddenAbilities,
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
                    defensiveTypeEffectiveness:
                        _viewModel.defensiveTypeEffectiveness,
                    offensiveTypeEffectiveness:
                        _viewModel.offensiveTypeEffectiveness,
                  ),
                ),

                // Moves
                const SizedBox(height: 28),
                Text(
                  'Moves',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                FlatCard(
                  padding: const EdgeInsets.all(16),
                  elevation: 1,
                  borderRadius: BorderRadius.circular(16),
                  child: MovesCard(
                    baseName: pokemon.baseName,
                    variant: pokemon.name,
                  ),
                ),

                const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              // Pokemon image positioned absolutely (appears on top)
              Positioned(
                top: -100,
                left: 14,
                child: Hero(
                  tag: 'pokemon-image-${pokemon.number}-${pokemon.variant ?? 'base'}',
                  child: PokemonImage(
                    imagePath: pokemon.imagePath,
                    imagePathLarge: pokemon.imagePathLarge,
                    size: 200,
                    useLarge: true,
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }
}

class _AbilitiesCard extends StatelessWidget {
  final List<String> regularAbilities;
  final List<String> hiddenAbilities;

  const _AbilitiesCard({
    required this.regularAbilities,
    required this.hiddenAbilities,
  });

  bool get _hasAnyAbilities =>
      regularAbilities.isNotEmpty || hiddenAbilities.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unknownStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );

    Widget buildColumn({
      required String title,
      required List<String> abilities,
      required Color color,
    }) {
      if (abilities.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AbilityGroupTitle(title),
            const SizedBox(height: 8),
            Text('Unknown', style: unknownStyle),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AbilityGroupTitle(title),
          const SizedBox(height: 8),
          ...abilities.map(
            (ability) => _AbilityListItem(
              ability: ability,
              color: color,
            ),
          ),
        ],
      );
    }

    return FlatCard(
      padding: const EdgeInsets.all(16),
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: !_hasAnyAbilities
          ? Text('Unknown', style: unknownStyle)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: buildColumn(
                    title: 'Abilities',
                    abilities: regularAbilities,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: buildColumn(
                    title: 'Hidden Ability',
                    abilities: hiddenAbilities,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
    );
  }
}

class _AbilityGroupTitle extends StatelessWidget {
  final String title;

  const _AbilityGroupTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _AbilityListItem extends StatefulWidget {
  final String ability;
  final Color color;

  const _AbilityListItem({
    required this.ability,
    required this.color,
  });

  @override
  State<_AbilityListItem> createState() => _AbilityListItemState();
}

class _AbilityListItemState extends State<_AbilityListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pushNamed(
              '/ability-detail',
              arguments: widget.ability,
            );
          },
          onHover: (hovering) {
            setState(() {
              _isHovered = hovering;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isHovered
                    ? widget.color
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.ability,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: _isHovered
                      ? widget.color
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}