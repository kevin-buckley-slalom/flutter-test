import 'package:flutter/material.dart';
import '../../../data/models/pokemon.dart';
import '../../../data/models/type_effectiveness.dart';
import 'type_effectiveness_compact.dart';
import 'type_icon.dart';

class TypeEffectivenessTabs extends StatefulWidget {
  final Pokemon pokemon;
  final TypeEffectiveness defensiveTypeEffectiveness;
  final Map<String, Map<String, Effectiveness>> offensiveTypeEffectiveness;

  const TypeEffectivenessTabs({
    super.key,
    required this.pokemon,
    required this.defensiveTypeEffectiveness,
    required this.offensiveTypeEffectiveness,
  });

  @override
  State<TypeEffectivenessTabs> createState() => _TypeEffectivenessTabsState();
}

class _TypeEffectivenessTabsState extends State<TypeEffectivenessTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 1 + widget.pokemon.types.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor:
                theme.colorScheme.onSurface.withOpacity(0.6),
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 80),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield, size: 18),
                        SizedBox(width: 6),
                        Text('Defense'),
                      ],
                    ),
                  ),
                ),
              ),
              ...widget.pokemon.types.map((type) {
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TypeIcon(type: type, size: 16),
                      const SizedBox(width: 6),
                      Text(type),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _buildTabContent(),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    final currentIndex = _tabController.index;

    if (currentIndex == 0) {
      // Defensive tab
      return TypeEffectivenessCompact(
        defensiveEffectiveness:
            widget.defensiveTypeEffectiveness.effectivenessMap,
      );
    } else {
      // Offensive tabs
      final typeIndex = currentIndex - 1;
      final type = widget.pokemon.types[typeIndex];
      final offensiveMap = widget.offensiveTypeEffectiveness[type];

      return TypeEffectivenessCompact(
        offensiveEffectiveness: offensiveMap,
      );
    }
  }
}
