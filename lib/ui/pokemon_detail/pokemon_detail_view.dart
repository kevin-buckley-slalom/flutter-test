import 'package:flutter/material.dart';
import '../../data/models/pokemon.dart';
import '../shared/parallax_scroll_container.dart';
import 'pokemon_detail_view_model.dart';
import 'widgets/abilities_card.dart';
import 'widgets/controls_section.dart';
import 'widgets/moves_section.dart';
import 'widgets/pokemon_header_section.dart';
import 'widgets/pokemon_image_with_sparkles.dart';
import 'widgets/stats_section.dart';
import 'widgets/type_effectiveness_section.dart';
import 'widgets/vitals_card.dart';

class PokemonDetailView extends StatefulWidget {
  final Pokemon pokemon;

  const PokemonDetailView({
    super.key,
    required this.pokemon,
  });

  @override
  State<PokemonDetailView> createState() => _PokemonDetailViewState();
}

class _PokemonDetailViewState extends State<PokemonDetailView> {
  late final PokemonDetailViewModel _viewModel;
  bool _showShiny = false;
  String? _selectedAltImage;

  @override
  void initState() {
    super.initState();
    _viewModel = PokemonDetailViewModel.fromPokemon(widget.pokemon);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Vitals formatting
    final classification = widget.pokemon.classification ?? 'Unknown';
    final captureRate = widget.pokemon.captureRate?.toString() ?? 'Unknown';
    String formatGender(Map<String, dynamic>? ratio) {
      if (ratio == null || ratio.isEmpty) return 'Gender Unknown';
      final male = ratio['male'];
      final female = ratio['female'];
      if (male != null && female != null) {
        return '♂ $male% / ♀ $female%';
      }
      return ratio.toString();
    }

    final genderRatioString = formatGender(widget.pokemon.genderRatio);

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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Image.asset(
              (_showShiny && widget.pokemon.imageShinyPath != null)
                  ? widget.pokemon.imageShinyPath!
                  : (widget.pokemon.imagePath ??
                      'pokemon/placeholder_pokemon.png'),
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                final placeholderName = _showShiny
                    ? 'placeholder_pokemon_shiny.png'
                    : 'placeholder_pokemon.png';
                return Image.asset(
                  'assets/images/pokemon/$placeholderName',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(width: 40, height: 40);
                  },
                );
              },
            ),
          ),
        ],
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
                      width: 2),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28), bottom: Radius.circular(28)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26), bottom: Radius.circular(26)),
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
                              theme.colorScheme.surface.withValues(alpha: 0.5),
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
                  // Header: Pokemon number, name, variant
                  PokemonHeaderSection(
                    pokemon: widget.pokemon,
                    classification: classification,
                  ),
                  // Buttons and type chips
                  const SizedBox(height: 20),
                  ControlsSection(
                    pokemon: widget.pokemon,
                    showShiny: _showShiny,
                    onShinyToggled: () {
                      setState(() {
                        _showShiny = !_showShiny;
                      });
                    },
                    selectedAltImage: _selectedAltImage,
                    onAltImageSelected: (altImage) {
                      setState(() {
                        _selectedAltImage = altImage;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  // Vitals - compact layout
                  VitalsCard(
                    pokemon: widget.pokemon,
                    classification: classification,
                    genderRatioString: genderRatioString,
                    captureRate: captureRate,
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
                  AbilitiesCard(
                    regularAbilities: widget.pokemon.regularAbilities,
                    hiddenAbilities: widget.pokemon.hiddenAbilities,
                  ),

                  // Base Stats
                  const SizedBox(height: 32),
                  StatsSection(
                    pokemon: widget.pokemon,
                  ),

                  // Type Effectiveness
                  const SizedBox(height: 28),
                  TypeEffectivenessSection(
                    pokemon: widget.pokemon,
                    defensiveTypeEffectiveness:
                        _viewModel.defensiveTypeEffectiveness,
                    offensiveTypeEffectiveness:
                        _viewModel.offensiveTypeEffectiveness,
                  ),

                  // Moves
                  const SizedBox(height: 28),
                  MovesSection(
                    baseName: widget.pokemon.baseName,
                    variant: widget.pokemon.name,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
            // Pokemon image with sparkle animation
            PokemonImageWithSparkles(
              pokemon: widget.pokemon,
              showShiny: _showShiny,
              selectedAltImage: _selectedAltImage,
              onShinyToggled: (isShiny) {
                if (isShiny) {
                  // Parent widget handles shiny state changes
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
