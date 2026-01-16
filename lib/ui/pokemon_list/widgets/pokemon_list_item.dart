import 'package:flutter/material.dart';
import '../../../app/theme/type_colors.dart';
import '../../../data/models/pokemon.dart';
import '../../shared/placeholder_image.dart';
import '../../shared/flat_card.dart';

class PokemonListItem extends StatelessWidget {
  final Pokemon pokemon;
  final VoidCallback onTap;
  final String? statField;

  const PokemonListItem({
    super.key,
    required this.pokemon,
    required this.onTap,
    this.statField,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FlatCard(
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Pokemon Image
            Hero(
              tag: 'pokemon-image-${pokemon.number}-${pokemon.variant ?? 'base'}',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.primary.withOpacity(0.08),
                ),
                child: const PlaceholderImage(
                  width: 80,
                  height: 80,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Info Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Number
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pokemon.baseName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '#${pokemon.number.toString().padLeft(3, '0')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  
                  // Variant badge (if exists)
                  if (pokemon.variant != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pokemon.variant!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 8),
                  
                  // Types
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: pokemon.types.map((type) {
                      final typeColor = TypeColors.getColor(type);
                      final textColor = TypeColors.getTextColor(type);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Stats Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getStatLabel(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getStatValue()}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatLabel() {
    switch (statField) {
      case 'hp':
        return 'HP';
      case 'attack':
        return 'ATK';
      case 'defense':
        return 'DEF';
      case 'spAtk':
        return 'SPA';
      case 'spDef':
        return 'SPD';
      case 'speed':
        return 'SPE';
      default:
        return 'BST';
    }
  }

  int _getStatValue() {
    switch (statField) {
      case 'hp':
        return pokemon.stats.hp;
      case 'attack':
        return pokemon.stats.attack;
      case 'defense':
        return pokemon.stats.defense;
      case 'spAtk':
        return pokemon.stats.spAtk;
      case 'spDef':
        return pokemon.stats.spDef;
      case 'speed':
        return pokemon.stats.speed;
      default:
        return pokemon.stats.total;
    }
  }
}