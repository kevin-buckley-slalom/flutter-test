import 'package:flutter/material.dart';
import '../../../data/models/pokemon.dart';
import '../../../ui/shared/flat_card.dart';
import 'type_effectiveness_tabs.dart';

class TypeEffectivenessSection extends StatelessWidget {
  final Pokemon pokemon;
  final dynamic defensiveTypeEffectiveness;
  final dynamic offensiveTypeEffectiveness;

  const TypeEffectivenessSection({
    super.key,
    required this.pokemon,
    required this.defensiveTypeEffectiveness,
    required this.offensiveTypeEffectiveness,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            defensiveTypeEffectiveness: defensiveTypeEffectiveness,
            offensiveTypeEffectiveness: offensiveTypeEffectiveness,
          ),
        ),
      ],
    );
  }
}
