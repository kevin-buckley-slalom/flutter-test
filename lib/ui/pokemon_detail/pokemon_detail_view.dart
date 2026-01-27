import 'dart:math' show cos, sin;

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

class PokemonDetailView extends StatefulWidget {
  final Pokemon pokemon;

  PokemonDetailView({
    super.key,
    required this.pokemon,
  });

  @override
  State<PokemonDetailView> createState() => _PokemonDetailViewState();
}

class _PokemonDetailViewState extends State<PokemonDetailView>
    with SingleTickerProviderStateMixin {
  late final PokemonDetailViewModel _viewModel;
  bool _showShiny = false;
  late final AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _viewModel = PokemonDetailViewModel.fromPokemon(widget.pokemon);
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Vitals formatting
    final classification = widget.pokemon.classification ?? 'Unknown';
    final heightImperial = widget.pokemon.heightImperial ?? 'Unknown';
    final heightMetric = widget.pokemon.heightMetric ?? 'Unknown';
    final weightImperial = widget.pokemon.weightImperial ?? 'Unknown';
    final weightMetric = widget.pokemon.weightMetric ?? 'Unknown';
    final captureRate = widget.pokemon.captureRate?.toString() ?? 'Unknown';
    String formatGender(Map<String, dynamic>? ratio) {
      if (ratio == null || ratio.isEmpty) return 'Gender Unknown';
      final male = ratio['male'];
      final female = ratio['female'];
      if (male != null && female != null) {
        return '♂ ${male}% / ♀ ${female}%';
      }
      return ratio.toString();
    }
    final genderRatioString = formatGender(widget.pokemon.genderRatio);

    final currentImagePath = _showShiny
      ? (widget.pokemon.imageShinyPath ?? widget.pokemon.imagePath)
      : widget.pokemon.imagePath;
    final currentImagePathLarge = _showShiny
      ? (widget.pokemon.imageShinyPathLarge ?? widget.pokemon.imagePathLarge)
      : widget.pokemon.imagePathLarge;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.pokemon.baseName),
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
                'assets/images/backdrops/${widget.pokemon.backdropPath}',
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
          ],
        ),
        contentChild: Stack(
          clipBehavior: Clip.none,
          children: [
              // Background layer with gradient and solid color
              Positioned.fill(
                child: DecoratedBox(
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
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26),
                      bottom: Radius.circular(26)
                    ),
                    child: Column(
                      children: [
                        // Fixed height gradient at top
                        Container(
                          height: 175,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.colorScheme.surface.withValues(alpha: 0.3),
                                theme.colorScheme.surface.withValues(alpha: 0.9),
                                theme.colorScheme.surface,
                              ],
                            ),
                          ),
                        ),
                        // Solid background for the rest
                        Expanded(
                          child: Container(
                            color: theme.colorScheme.surface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Card content on top
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // Two columns: left with types under image, right with name info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left column: types
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: const [
                                SizedBox(height: 100),
                              ],
                            ),
                          ),
                          // Right column: name, variant, number
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                // Pokemon number
                                Text(
                                  '#${widget.pokemon.number.toString().padLeft(3, '0')}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                  // Pokemon base name
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    widget.pokemon.baseName,
                                    style: theme.textTheme.headlineLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Variant or Classification
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    widget.pokemon.variant ?? classification,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                            ),
                          ),
                        ],
                      ),
                      // Buttons and type chips aligned on one row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: IconButton.outlined(
                                      isSelected: _showShiny,
                                      onPressed: () {
                                        final next = !_showShiny;
                                        setState(() {
                                          _showShiny = next;
                                        });
                                        if (next) {
                                          _sparkleController.forward(from: 0);
                                        }
                                      },
                                      icon: const Icon(Icons.star_border),
                                      selectedIcon: const Icon(Icons.star),
                                      style: IconButton.styleFrom(
                                        foregroundColor: _showShiny
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.primary
                                                .withValues(alpha: 0.7),
                                        side: BorderSide(
                                          color: _showShiny
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                        ),
                                        backgroundColor: _showShiny
                                            ? theme.colorScheme.primary
                                                .withValues(alpha: 0.08)
                                            : Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(7),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {},
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.colorScheme.primary.withValues(alpha: 0.7),
                                      side: BorderSide(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                    ),
                                    child: const Icon(Icons.image),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ...widget.pokemon.types.map(
                                    (type) => Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: TypeChip(type: type),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Vitals - compact layout
                      FlatCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        elevation: 0,
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row: Height | Weight
                            Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Row(
                                    children: [
                                      Text(
                                        'Height:',
                                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '$heightImperial / $heightMetric',
                                        style: theme.textTheme.bodyMedium,
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 6,
                                  child: Row(
                                    children: [
                                      Text(
                                        'Weight:',
                                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '$weightImperial / $weightMetric',
                                        style: theme.textTheme.bodyMedium,
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            // Row: Gender Ratio | Capture Rate
                            Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Row(
                                    children: [
                                      const Spacer(),
                                      Text(
                                        genderRatioString,
                                        style: theme.textTheme.bodyMedium,
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 6,
                                  child: Row(
                                    children: [
                                      Text(
                                        'Catch Rate:',
                                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      const Spacer(),
                                      Text(
                                        captureRate,
                                        style: theme.textTheme.bodyMedium,
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Abilities
                      const SizedBox(height: 20),
                      Text(
                        'Abilities',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AbilitiesCard(
                        regularAbilities: widget.pokemon.regularAbilities,
                        hiddenAbilities: widget.pokemon.hiddenAbilities,
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
                        value: widget.pokemon.stats.hp,
                      ),
                      StatBarChart(
                        statName: 'attack',
                        value: widget.pokemon.stats.attack,
                      ),
                      StatBarChart(
                        statName: 'defense',
                        value: widget.pokemon.stats.defense,
                      ),
                      StatBarChart(
                        statName: 'sp_atk',
                        value: widget.pokemon.stats.spAtk,
                      ),
                      StatBarChart(
                        statName: 'sp_def',
                        value: widget.pokemon.stats.spDef,
                      ),
                      StatBarChart(
                        statName: 'speed',
                        value: widget.pokemon.stats.speed,
                      ),
                      StatBarChart(
                        statName: 'BST',
                        value: widget.pokemon.stats.total,
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
                    pokemon: widget.pokemon,
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
                    baseName: widget.pokemon.baseName,
                    variant: widget.pokemon.name,
                  ),
                ),

                const SizedBox(height: 32),
                  ],
                ),
              ),
              // Pokemon image positioned absolutely (appears on top)
              Positioned(
                top: -100,
                left: 10,
                child: AnimatedBuilder(
                  animation: _sparkleController,
                  builder: (context, child) {
                    // Calculate white fade overlay opacity
                    // Fades in at 0-50%, peaks at 50%, fades out at 50-100%
                    double overlayOpacity = 0.0;
                    if (_sparkleController.value <= 0.5) {
                      overlayOpacity = _sparkleController.value * 2; // 0 to 1
                    } else {
                      overlayOpacity = (1 - _sparkleController.value) * 2; // 1 to 0
                    }
                    
                    return Hero(
                      tag:
                          'pokemon-image-${widget.pokemon.number}-${widget.pokemon.variant ?? 'base'}-${_showShiny ? 'shiny' : 'regular'}',
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix([
                          1 - overlayOpacity, 0, 0, 0, overlayOpacity * 255,
                          0, 1 - overlayOpacity, 0, 0, overlayOpacity * 255,
                          0, 0, 1 - overlayOpacity, 0, overlayOpacity * 255,
                          0, 0, 0, 1, 0,
                        ]),
                        child: PokemonImage(
                          imagePath: currentImagePath,
                          imagePathLarge: currentImagePathLarge,
                          size: 200,
                          useLarge: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Sparkle overlay when toggling shiny
              Positioned(
                top: -90,
                left: -10,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: AnimatedBuilder(
                      animation: _sparkleController,
                      builder: (context, child) {
                        if (_sparkleController.value == 0) {
                          return const SizedBox();
                        }
                        return _buildCircleStars(theme);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildCircleStars(ThemeData theme) {
    const int numStars = 8;
    const double radius = 60.0;
    final List<Widget> stars = [];

    for (int i = 0; i < numStars; i++) {
      // Calculate angle for this star (starting at 12 o'clock, going clockwise)
      final angle = (i / numStars) * 2 * 3.14159 - (3.14159 / 2);
      
      // Position on circle
      final x = radius * cos(angle);
      final y = radius * sin(angle);
      
      // Calculate which star is currently the "lead" based on animation progress
      final currentLeadPosition = (_sparkleController.value * numStars);
      
      // Distance from this star's position to the current lead
      // Account for wrap-around
      double distanceFromLead = (i - currentLeadPosition) % numStars;
      if (distanceFromLead < 0) distanceFromLead += numStars;
      
      // Stars in the "train" behind the lead (within 3 positions)
      final inTrail = distanceFromLead <= 3;
      
      // Opacity and size based on position in trail
      double opacity = 0.0;
      double size = 0.0;
      
      if (inTrail) {
        // Lead star is largest and fully visible
        // Trailing stars fade out and shrink
        final trailPosition = distanceFromLead / 3.0; // 0 = lead, 1 = end of trail
        opacity = Curves.easeOut.transform(1.0 - trailPosition);
        size = 48.0 - (trailPosition * 24.0); // 48 down to 24
        
        // Fade out all stars in the final 15% of the animation
        if (_sparkleController.value > 0.85) {
          final globalFadeOut = (_sparkleController.value - 0.85) / 0.15;
          opacity *= (1.0 - globalFadeOut);
        }
      }
      
      stars.add(
        Positioned(
          left: 120 + x - (size / 2),
          top: 120 + y - (size / 2),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Icon(
              size == 48 ? Icons.star_rounded : Icons.star_border_rounded,
              size: size,
              color: Colors.amber.shade800,
            ),
          ),
        ),
      );
    }
    
    return Stack(children: stars);
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