import 'package:flutter/material.dart';
import '../../../app/theme/type_colors.dart';
import '../../../data/models/type_effectiveness.dart';

class TypeEffectivenessGrid extends StatelessWidget {
  final TypeEffectiveness? defensiveTypeEffectiveness;
  final Map<String, Map<String, Effectiveness>>? offensiveTypeEffectiveness;
  final String? offensiveType;

  const TypeEffectivenessGrid({
    super.key,
    this.defensiveTypeEffectiveness,
    this.offensiveTypeEffectiveness,
    this.offensiveType,
  });

  @override
  Widget build(BuildContext context) {
    // Display defensive effectiveness if provided
    if (defensiveTypeEffectiveness != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (defensiveTypeEffectiveness!.extremeWeaknesses.isNotEmpty) ...[
            _buildSection(
              context,
              'Extreme Weaknesses (4x)',
              defensiveTypeEffectiveness!.extremeWeaknesses,
              Colors.deepOrange.shade900,
              Icons.crisis_alert,
            ),
            const SizedBox(height: 16),
          ],
          if (defensiveTypeEffectiveness!.weaknesses.isNotEmpty) ...[
            _buildSection(
              context,
              'Weaknesses (2x)',
              defensiveTypeEffectiveness!.weaknesses,
              Colors.red.shade400,
              Icons.dangerous,
            ),
            const SizedBox(height: 16),
          ],
          if (defensiveTypeEffectiveness!.resistances.isNotEmpty) ...[
            _buildSection(
              context,
              'Resistances (0.5x)',
              defensiveTypeEffectiveness!.resistances,
              Colors.blue.shade400,
              Icons.security,
            ),
            const SizedBox(height: 16),
          ],
          if (defensiveTypeEffectiveness!.hardlyEffective.isNotEmpty) ...[
            _buildSection(
              context,
              'Double Resistance (0.25x)',
              defensiveTypeEffectiveness!.hardlyEffective,
              Colors.cyan.shade300,
              Icons.add_moderator,
            ),
            const SizedBox(height: 16),
          ],
          if (defensiveTypeEffectiveness!.immunities.isNotEmpty) ...[
            _buildSection(
              context,
              'Immunities (0x)',
              defensiveTypeEffectiveness!.immunities,
              Colors.grey.shade400,
              Icons.block,
            ),
            const SizedBox(height: 16),
          ],
        ],
      );
    }
    
    // Display offensive effectiveness if provided
    if (offensiveTypeEffectiveness != null && offensiveType != null) {
      final effectiveness = offensiveTypeEffectiveness![offensiveType!];
      if (effectiveness == null) {
        return const SizedBox.shrink();
      }
      
      final immunities = <String>[];
      final superEffective = <String>[];
      final notVeryEffective = <String>[];
      
      effectiveness.forEach((type, eff) {
        if (eff == Effectiveness.immune) {
          immunities.add(type);
        } else if (eff == Effectiveness.superEffective) {
          superEffective.add(type);
        } else if (eff == Effectiveness.notVeryEffective) {
          notVeryEffective.add(type);
        }
      });

      immunities.sort();
      superEffective.sort();
      notVeryEffective.sort();
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (immunities.isNotEmpty) ...[
            _buildSection(
              context,
              'No Effect (0x)',
              immunities,
              Colors.grey.shade400,
              Icons.block,
            ),
            const SizedBox(height: 16),
          ],
          if (superEffective.isNotEmpty) ...[
            _buildSection(
              context,
              'Super Effective (2x)',
              superEffective,
              Colors.green.shade400,
              Icons.keyboard_double_arrow_up_rounded,
            ),
            const SizedBox(height: 16),
          ],
          if (notVeryEffective.isNotEmpty) ...[
            _buildSection(
              context,
              'Not Very Effective (0.5x)',
              notVeryEffective,
              Colors.orange.shade400,
              Icons.keyboard_double_arrow_down_rounded,
            ),
          ],
        ],
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<String> types,
    Color backgroundColor,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: backgroundColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((type) {
            final typeColor = TypeColors.getColor(type);
            final textColor = TypeColors.getTextColor(type);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}




