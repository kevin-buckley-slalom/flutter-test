import 'package:flutter/material.dart';
import '../../../data/models/pokemon.dart';
import '../../../ui/shared/flat_card.dart';

class VitalsCard extends StatelessWidget {
  final Pokemon pokemon;
  final String classification;
  final String genderRatioString;
  final String captureRate;

  const VitalsCard({
    super.key,
    required this.pokemon,
    required this.classification,
    required this.genderRatioString,
    required this.captureRate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heightImperial = pokemon.heightImperial ?? 'Unknown';
    final heightMetric = pokemon.heightMetric ?? 'Unknown';
    final weightImperial = pokemon.weightImperial ?? 'Unknown';
    final weightMetric = pokemon.weightMetric ?? 'Unknown';

    return FlatCard(
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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
    );
  }
}
