import 'package:flutter/material.dart';
import '../../../ui/shared/flat_card.dart';
import 'moves_card.dart';

class MovesSection extends StatelessWidget {
  final String baseName;
  final String variant;

  const MovesSection({
    super.key,
    required this.baseName,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            baseName: baseName,
            variant: variant,
          ),
        ),
      ],
    );
  }
}
