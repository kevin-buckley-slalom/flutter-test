import 'package:flutter/material.dart';
import '../../../data/models/pokemon.dart';
import '../../../ui/shared/flat_card.dart';
import 'stat_bar_chart.dart';

class StatsSection extends StatelessWidget {
  final Pokemon pokemon;

  const StatsSection({
    super.key,
    required this.pokemon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
}
