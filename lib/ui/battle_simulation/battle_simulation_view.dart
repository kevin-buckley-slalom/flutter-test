import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:championdex/ui/battle_simulation/battle_simulation_view_model.dart';
import 'package:championdex/ui/battle_simulation/widgets/battle_field_widget.dart';
import 'package:championdex/ui/battle_simulation/widgets/field_conditions_widget.dart';
import 'package:championdex/ui/battle_simulation/widgets/pokemon_config_bottom_sheet.dart';
import 'package:championdex/ui/battle_simulation/widgets/simulation_event_widget.dart';
import 'package:championdex/ui/moves_list/moves_list_view_model.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';

class BattleSimulationView extends ConsumerStatefulWidget {
  final String team1Id;
  final String team2Id;
  final bool isSingles;

  const BattleSimulationView({
    super.key,
    required this.team1Id,
    required this.team2Id,
    required this.isSingles,
  });

  @override
  ConsumerState<BattleSimulationView> createState() =>
      _BattleSimulationViewState();
}

class _BattleSimulationViewState extends ConsumerState<BattleSimulationView> {
  late ScrollController _scrollController;
  late ScrollController _logScrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _logScrollController = ScrollController();
    // Initialize battle
    Future.microtask(() {
      ref.read(battleSimulationViewModelProvider.notifier).initializeBattle(
            team1Id: widget.team1Id,
            team2Id: widget.team2Id,
            isSingles: widget.isSingles,
          );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final battleState = ref.watch(battleSimulationViewModelProvider);

    if (battleState == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Battle Simulation')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${battleState.team1Name} vs ${battleState.team2Name}'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Main scrollable content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Spacer for battlefield height
              SliverToBoxAdapter(
                child: SizedBox(height: 350), // Battlefield height
              ),
              // Field Conditions Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Field Conditions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        FieldConditionsWidget(
                          onFieldConditionChanged: (category, value) {
                            ref
                                .read(
                                    battleSimulationViewModelProvider.notifier)
                                .setFieldCondition(category, value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Simulation Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Run Simulation Button
                      ElevatedButton.icon(
                        onPressed: battleState.allActionsSet
                            ? () {
                                ref
                                    .read(battleSimulationViewModelProvider
                                        .notifier)
                                    .startSimulation();
                              }
                            : null,
                        icon: Icon(Icons.play_arrow),
                        label: Text('Run Simulation'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 48),
                        ),
                      ),
                      if (!battleState.allActionsSet)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'All battlefield Pokémon must have actions set',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: Colors.orange),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Simulation Log Header (sticky)
              if (battleState.simulationLog.isNotEmpty)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeaderDelegate(
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Simulation Log',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    ref
                                        .read(battleSimulationViewModelProvider
                                            .notifier)
                                        .clearSimulationLog();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Simulation Log Items
              if (battleState.simulationLog.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return SimulationEventWidget(
                          event: battleState.simulationLog[index],
                          eventIndex: index,
                          isModified:
                              battleState.simulationLog[index].isModified,
                          needsRecalculation: battleState
                              .simulationLog[index].needsRecalculation,
                          onModify: (modification) {
                            ref
                                .read(
                                    battleSimulationViewModelProvider.notifier)
                                .modifyEventOutcome(index, modification);
                          },
                          onRerunFromHere: () {
                            ref
                                .read(
                                    battleSimulationViewModelProvider.notifier)
                                .rerunFromEvent(index);
                          },
                        );
                      },
                      childCount: battleState.simulationLog.length,
                    ),
                  ),
                ),
              // Bottom padding
              SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),
            ],
          ),
          // Fixed battlefield widget floating on top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BattleFieldWidget(
              team1Name: battleState.team1Name,
              team2Name: battleState.team2Name,
              team1Pokemon: battleState.team1Pokemon,
              team2Pokemon: battleState.team2Pokemon,
              onPokemonTap: (isTeam1, slotIndex) async {
                await _showPokemonConfig(
                    context, ref, battleState, isTeam1, slotIndex);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPokemonConfig(
    BuildContext context,
    WidgetRef ref,
    BattleUiState battleState,
    bool isTeam1,
    int slotIndex,
  ) async {
    final pokemon = isTeam1
        ? battleState.team1Pokemon[slotIndex]
        : battleState.team2Pokemon[slotIndex];

    if (pokemon == null) return;

    final benchTeam = isTeam1 ? battleState.team1Bench : battleState.team2Bench;

    // Collect all pokemon currently on the field
    final fieldPokemon = [
      ...battleState.team1Pokemon.where((p) => p != null).cast<BattlePokemon>(),
      ...battleState.team2Pokemon.where((p) => p != null).cast<BattlePokemon>(),
    ];

    // Get available moves from the pokemon
    final availableMoves = pokemon.moves;

    await showPokemonConfigBottomSheet(
      context,
      pokemon: pokemon,
      benchPokemon: benchTeam,
      fieldPokemon: fieldPokemon,
      team1Pokemon: battleState.team1Pokemon,
      team2Pokemon: battleState.team2Pokemon,
      availableMoves: availableMoves,
      moveRepository: ref.read(moveRepositoryProvider),
      onActionSet: (action) {
        ref.read(battleSimulationViewModelProvider.notifier).setQueuedAction(
              isTeam1,
              slotIndex,
              action,
            );
      },
      onHpChanged: (hp) {
        ref.read(battleSimulationViewModelProvider.notifier).setCurrentHp(
              isTeam1,
              slotIndex,
              hp,
            );
      },
      onStatStagesChanged: (statStages) {
        // Update each stat stage
        for (final entry in statStages.entries) {
          ref.read(battleSimulationViewModelProvider.notifier).setStatStage(
                isTeam1,
                slotIndex,
                entry.key,
                entry.value,
              );
        }
      },
      onPokemonChanged: (newPokemon) {
        // Switch the pokemon in the configuration
        ref.read(battleSimulationViewModelProvider.notifier).switchPokemon(
              isTeam1,
              slotIndex,
              newPokemon,
            );
      },
    );
  }
}

// Sticky header delegate for the simulation log header
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => 80;

  @override
  double get maxExtent => 80;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return false;
  }
}
