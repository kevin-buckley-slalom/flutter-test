import 'package:flutter/material.dart';
import '../../../ui/shared/flat_card.dart';

class AbilitiesCard extends StatelessWidget {
  final List<String> regularAbilities;
  final List<String> hiddenAbilities;

  const AbilitiesCard({
    super.key,
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
