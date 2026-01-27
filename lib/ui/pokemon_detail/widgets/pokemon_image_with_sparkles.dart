import 'dart:math' show cos, sin;

import 'package:flutter/material.dart';
import '../../../data/models/pokemon.dart';
import '../../../ui/shared/pokemon_image.dart';

class PokemonImageWithSparkles extends StatefulWidget {
  final Pokemon pokemon;
  final bool showShiny;
  final String? selectedAltImage;
  final Function(bool) onShinyToggled;

  const PokemonImageWithSparkles({
    super.key,
    required this.pokemon,
    required this.showShiny,
    this.selectedAltImage,
    required this.onShinyToggled,
  });

  @override
  State<PokemonImageWithSparkles> createState() =>
      _PokemonImageWithSparklesState();
}

class _PokemonImageWithSparklesState extends State<PokemonImageWithSparkles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didUpdateWidget(covariant PokemonImageWithSparkles oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger sparkle animation when showShiny changes to true
    if (!oldWidget.showShiny && widget.showShiny) {
      _sparkleController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine which image to use
    String? currentImagePath;
    String? currentImagePathLarge;

    if (widget.selectedAltImage != null) {
      // Use alt image
      if (widget.showShiny) {
        final withoutExt = widget.selectedAltImage!.replaceAll('.png', '');
        currentImagePath = '${withoutExt}_shiny.png';
        currentImagePathLarge = '${withoutExt}_shiny.png';
      } else {
        currentImagePath = widget.selectedAltImage;
        currentImagePathLarge = widget.selectedAltImage;
      }
    } else {
      // Use normal image
      currentImagePath = widget.showShiny
          ? (widget.pokemon.imageShinyPath ?? widget.pokemon.imagePath)
          : widget.pokemon.imagePath;
      currentImagePathLarge = widget.showShiny
          ? (widget.pokemon.imageShinyPathLarge ??
              widget.pokemon.imagePathLarge)
          : widget.pokemon.imagePathLarge;
    }

    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
                      'pokemon-image-${widget.pokemon.number}-${widget.pokemon.variant ?? 'base'}-${widget.showShiny ? 'shiny' : 'regular'}',
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix([
                      1 - overlayOpacity,
                      0,
                      0,
                      0,
                      overlayOpacity * 255,
                      0,
                      1 - overlayOpacity,
                      0,
                      0,
                      overlayOpacity * 255,
                      0,
                      0,
                      1 - overlayOpacity,
                      0,
                      overlayOpacity * 255,
                      0,
                      0,
                      0,
                      1,
                      0,
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
        final trailPosition =
            distanceFromLead / 3.0; // 0 = lead, 1 = end of trail
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
