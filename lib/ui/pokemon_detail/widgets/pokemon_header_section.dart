import 'package:flutter/material.dart';
import '../../../data/models/pokemon.dart';

class PokemonHeaderSection extends StatelessWidget {
  final Pokemon pokemon;
  final String classification;

  const PokemonHeaderSection({
    super.key,
    required this.pokemon,
    required this.classification,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: placeholder for image
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
                  '#${pokemon.number.toString().padLeft(3, '0')}',
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
                    pokemon.baseName,
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
                    pokemon.variant ?? classification,
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
    );
  }
}
