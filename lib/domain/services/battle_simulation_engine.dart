import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/domain/services/turn_order_calculator.dart';
import 'package:championdex/domain/services/damage_calculator.dart';
import 'package:championdex/domain/services/ability_effect_processor.dart';
import 'package:championdex/domain/services/item_effect_processor.dart';
import 'package:championdex/domain/services/simulation_event.dart';

/// Represents the outcome of a turn with all events and final states
class TurnOutcome {
  final List<SimulationEvent> events;
  final Map<String, BattlePokemon> finalStates; // pokemon name -> final state
  final List<BattlePokemon?>
      team1FinalField; // final field for team 1 (by slot)
  final List<BattlePokemon?>
      team2FinalField; // final field for team 2 (by slot)
  final List<BattlePokemon> team1FinalBench; // final bench for team 1
  final List<BattlePokemon> team2FinalBench; // final bench for team 2
  final Map<String, dynamic> probabilities; // outcome -> probability

  TurnOutcome({
    required this.events,
    required this.finalStates,
    required this.team1FinalField,
    required this.team2FinalField,
    required this.team1FinalBench,
    required this.team2FinalBench,
    required this.probabilities,
  });
}

/// Main battle simulation engine that processes a full turn
class BattleSimulationEngine {
  final Map<String, dynamic> moveDatabase; // move name -> Move
  final Map<String, List<String>> pokemonTypesMap; // pokemon name -> types
  late final DamageCalculator _damageCalculator;

  BattleSimulationEngine({
    required this.moveDatabase,
    required this.pokemonTypesMap,
  }) {
    _damageCalculator = DamageCalculator();
  }

  /// Initialize the damage calculator (must be called before processTurn)
  Future<void> initialize() async {
    await _damageCalculator.loadTypeChart();
  }

  /// Process a complete turn of battle
  ///
  /// Returns all events that occurred during the turn and final battle state
  TurnOutcome processTurn({
    required List<BattlePokemon> team1Active,
    required List<BattlePokemon> team2Active,
    required List<BattlePokemon> team1Bench,
    required List<BattlePokemon> team2Bench,
    required Map<String, BattleAction> actionsMap, // pokemonName -> action
    required Map<String, dynamic> fieldConditions,
  }) {
    final events = <SimulationEvent>[];
    final finalStates = <String, BattlePokemon>{};

    // Copy pokemon states to avoid mutations
    final allPokemon = <BattlePokemon>[
      ...team1Active,
      ...team2Active,
      ...team1Bench,
      ...team2Bench,
    ];
    for (final p in allPokemon) {
      finalStates[p.originalName] = _copyPokemon(p);
    }

    // Track which pokemon are on the field (for targeting purposes)
    final currentFieldTeam1 =
        team1Active.map((p) => finalStates[p.originalName]!).toList();
    final currentFieldTeam2 =
        team2Active.map((p) => finalStates[p.originalName]!).toList();

    // Track which pokemon are on the bench
    final currentBenchTeam1 =
        team1Bench.map((p) => finalStates[p.originalName]!).toList();
    final currentBenchTeam2 =
        team2Bench.map((p) => finalStates[p.originalName]!).toList();

    // Step 1: Calculate turn order for all actions
    final isTrickRoomActive = fieldConditions['trickRoom'] == true;
    final turnActions = TurnOrderCalculator.calculateTurnOrder(
      allActivePokemon: allPokemon,
      actionsMap: actionsMap,
      moveDatabase: moveDatabase,
      isTrickRoomActive: isTrickRoomActive,
      isChildsPlayActive: false, // TODO: implement
    );

    // Step 2: Separate and execute switches first (in speed order)
    final switchActions = <TurnAction>[];
    final moveActions = <TurnAction>[];

    for (final turnAction in turnActions) {
      if (turnAction.action is SwitchAction) {
        switchActions.add(turnAction);
      } else {
        moveActions.add(turnAction);
      }
    }

    // Execute switches in speed order
    for (final turnAction in switchActions) {
      final switchAction = turnAction.action as SwitchAction;
      final switchedOutPokemon = finalStates[turnAction.pokemon.originalName];

      if (switchedOutPokemon != null) {
        // Log the switch
        events.add(SimulationEvent(
          message: '${switchedOutPokemon.pokemonName} switched out!',
          type: SimulationEventType.summary,
        ));

        // Find the slot and swap pokemon in the field lists
        final isTeam1 = currentFieldTeam1
            .any((p) => p.originalName == switchedOutPokemon.originalName);
        final fieldList = isTeam1 ? currentFieldTeam1 : currentFieldTeam2;
        final benchList = isTeam1 ? currentBenchTeam1 : currentBenchTeam2;
        final slotIndex = fieldList.indexWhere(
            (p) => p.originalName == switchedOutPokemon.originalName);

        if (slotIndex >= 0) {
          final benchIndex = benchList.indexWhere((p) =>
              p.originalName == switchAction.targetPokemonName ||
              p.pokemonName == switchAction.targetPokemonName);

          if (benchIndex < 0) {
            continue;
          }

          final switchedInPokemon = benchList.removeAt(benchIndex);

          // Update field list with the switched-in pokemon
          fieldList[slotIndex] = switchedInPokemon;

          // Put the switched-out pokemon on the bench
          benchList.add(switchedOutPokemon);

          // Log the new pokemon entering
          events.add(SimulationEvent(
            message: 'Go! ${switchedInPokemon.pokemonName}!',
            type: SimulationEventType.summary,
            affectedPokemonName: switchedInPokemon.originalName,
          ));

          // Handle abilities on entry
          final opponent = _getOpponent(switchedInPokemon, finalStates,
              currentFieldTeam1, currentFieldTeam2);
          events.addAll(
            AbilityEffectProcessor.processSwitchInAbility(
                switchedInPokemon, opponent),
          );
        }
      }
    }

    // Step 3: Execute moves in turn order
    for (final turnAction in moveActions) {
      final pokemon = finalStates[turnAction.pokemon.originalName];
      if (pokemon == null || pokemon.currentHp <= 0)
        continue; // Pokemon is fainted

      if (turnAction.action is AttackAction) {
        final attackAction = turnAction.action as AttackAction;
        final moveData = moveDatabase[attackAction.moveName];

        if (moveData != null) {
          // Find the defender based on the target name or slot
          final defender = _findDefender(
            attackAction.targetPokemonName,
            pokemon,
            finalStates,
            currentFieldTeam1,
            currentFieldTeam2,
          );

          if (defender != null) {
            // Determine target count based on the target string
            final targetCount = _determineTargetCount(
              attackAction.targetPokemonName,
              currentFieldTeam1,
              currentFieldTeam2,
            );

            events.addAll(_executeMove(
              attacker: pokemon,
              defender: defender,
              move: moveData,
              fieldConditions: fieldConditions,
              targetCount: targetCount,
            ));

            // Post-move switching (e.g., Volt Switch/U-turn)
            if (attackAction.switchInPokemonName != null &&
                pokemon.currentHp > 0) {
              final isTeam1 = currentFieldTeam1
                  .any((p) => p.originalName == pokemon.originalName);
              final fieldList = isTeam1 ? currentFieldTeam1 : currentFieldTeam2;
              final benchList = isTeam1 ? currentBenchTeam1 : currentBenchTeam2;
              final slotIndex = fieldList
                  .indexWhere((p) => p.originalName == pokemon.originalName);

              if (slotIndex >= 0) {
                final benchIndex = benchList.indexWhere((p) =>
                    p.originalName == attackAction.switchInPokemonName ||
                    p.pokemonName == attackAction.switchInPokemonName);

                if (benchIndex >= 0) {
                  final switchedInPokemon = benchList.removeAt(benchIndex);

                  // Log the switch out/in
                  events.add(SimulationEvent(
                    message: '${pokemon.pokemonName} switched out!',
                    type: SimulationEventType.summary,
                  ));

                  fieldList[slotIndex] = switchedInPokemon;
                  benchList.add(pokemon);

                  events.add(SimulationEvent(
                    message: 'Go! ${switchedInPokemon.pokemonName}!',
                    type: SimulationEventType.summary,
                    affectedPokemonName: switchedInPokemon.originalName,
                  ));

                  final opponent = _getOpponent(switchedInPokemon, finalStates,
                      currentFieldTeam1, currentFieldTeam2);
                  events.addAll(
                    AbilityEffectProcessor.processSwitchInAbility(
                        switchedInPokemon, opponent),
                  );
                }
              }
            }
          }
        }
      }
    }

    // Step 4: End of turn effects
    // Passive healing, field damage, etc.
    for (final entry in finalStates.entries) {
      events.addAll(ItemEffectProcessor.processEndOfTurnItem(entry.value));
    }

    // Step 5: Generate outcome summary with probabilities
    final probabilities = _calculateOutcomeProbabilities(events, finalStates);

    return TurnOutcome(
      events: events,
      finalStates: finalStates,
      team1FinalField: currentFieldTeam1,
      team2FinalField: currentFieldTeam2,
      team1FinalBench: currentBenchTeam1,
      team2FinalBench: currentBenchTeam2,
      probabilities: probabilities,
    );
  }

  /// Execute a move and return all events that occur
  List<SimulationEvent> _executeMove({
    required BattlePokemon attacker,
    required BattlePokemon defender,
    required Move move,
    required Map<String, dynamic> fieldConditions,
    int targetCount = 1,
  }) {
    final events = <SimulationEvent>[];

    // Check if move hits
    final damageResult = _damageCalculator.calculateDamage(
      attacker: attacker,
      defender: defender,
      move: move,
      attackerTypes: pokemonTypesMap[attacker.pokemonName] ?? ['Normal'],
      defenderTypes: pokemonTypesMap[defender.pokemonName] ?? ['Normal'],
      targetCount: targetCount,
    );

    // Log move usage
    events.add(SimulationEvent(
      message: '${attacker.pokemonName} used ${move.name}!',
      type: SimulationEventType.move,
      affectedPokemonName: attacker.originalName,
    ));

    // Check hit chance
    if (damageResult.hitChance < 1.0) {
      // Calculate if move hits based on probability
      // For now, assume it always hits if probability > 50%
      if (damageResult.hitChance < 0.5) {
        events.add(SimulationEvent(
          message: '${attacker.pokemonName}\'s attack missed!',
          type: SimulationEventType.summary,
        ));
        return events;
      }
    }

    // Apply damage
    if (damageResult.maxDamage > 0) {
      final damageDealt = damageResult.averageDamage;
      final hpBefore = defender.currentHp;
      defender.currentHp =
          (defender.currentHp - damageDealt).clamp(0, defender.maxHp);
      final hpAfter = defender.currentHp;

      var message =
          '${defender.pokemonName} took $damageDealt damage! (range: ${damageResult.minDamage}-${damageResult.maxDamage})';

      if (damageResult.effectivenessString != null) {
        message = 'It\'s ${damageResult.effectivenessString}! $message';
      }

      if (damageResult.isTypeImmune) {
        message = 'It has no effect on ${defender.pokemonName}!';
        defender.currentHp = hpBefore;
      }

      events.add(SimulationEvent(
        message: message,
        type: SimulationEventType.damage,
        affectedPokemonName: defender.originalName,
        damageAmount: damageDealt,
        hpBefore: hpBefore,
        hpAfter: hpAfter,
      ));

      // Check for KO
      if (defender.currentHp <= 0) {
        events.add(SimulationEvent(
          message: '${defender.pokemonName} fainted!',
          type: SimulationEventType.summary,
          affectedPokemonName: defender.originalName,
        ));
      }
    }

    // Apply status effects from move
    if (move.effectChance != null && move.effectChance! > 0) {
      // Simplified: apply effect if chance > 50%
      if (move.effectChance! > 50) {
        // TODO: Parse effect from move.effect and apply
        events.add(SimulationEvent(
          message:
              '${defender.pokemonName} may be affected by ${move.name}\'s effect!',
          type: SimulationEventType.statusChange,
          affectedPokemonName: defender.originalName,
        ));
      }
    }

    // Item effects after move
    events.addAll(ItemEffectProcessor.processTurnItem(
      attacker,
      move.category,
      damageResult.maxDamage > 0,
      damageResult.averageDamage,
    ));

    return events;
  }

  /// Get the opponent of a given pokemon
  BattlePokemon? _getOpponent(
    BattlePokemon pokemon,
    Map<String, BattlePokemon> allStates,
    List<BattlePokemon> team1Active,
    List<BattlePokemon> team2Active,
  ) {
    // Determine which team the pokemon belongs to
    final isTeam1 =
        team1Active.any((p) => p.originalName == pokemon.originalName);
    final opponents = isTeam1 ? team2Active : team1Active;

    // Return first active opponent
    for (final opponent in opponents) {
      final hp = allStates[opponent.originalName]?.currentHp ?? 0;
      if (hp > 0) {
        return allStates[opponent.originalName];
      }
    }
    return null;
  }

  /// Find the defender for a move, accounting for slot-based targeting
  /// If the target is a specific pokemon name, find it; otherwise use opponent in slot
  BattlePokemon? _findDefender(
    String? targetName,
    BattlePokemon attacker,
    Map<String, BattlePokemon> allStates,
    List<BattlePokemon> currentFieldTeam1,
    List<BattlePokemon> currentFieldTeam2,
  ) {
    if (targetName == null) {
      // No specific target, use first active opponent
      return _getOpponent(
          attacker, allStates, currentFieldTeam1, currentFieldTeam2);
    }

    // Handle multi-target special cases
    if (targetName == 'all-opposing' ||
        targetName == 'all-field' ||
        targetName == 'all-team' ||
        targetName == 'all-except-user') {
      // For multi-target, return first opponent (actual damage will be handled separately)
      return _getOpponent(
          attacker, allStates, currentFieldTeam1, currentFieldTeam2);
    }

    // Try to find the specific pokemon by name in the current field
    final isTeam1 =
        currentFieldTeam1.any((p) => p.originalName == attacker.originalName);
    final opponentField = isTeam1 ? currentFieldTeam2 : currentFieldTeam1;

    for (final pokemon in opponentField) {
      if (pokemon.pokemonName == targetName ||
          pokemon.originalName == targetName) {
        final state = allStates[pokemon.originalName];
        if (state != null && state.currentHp > 0) {
          return state;
        }
      }
    }

    // If specific pokemon not found in opponent field, return first active opponent
    return _getOpponent(
        attacker, allStates, currentFieldTeam1, currentFieldTeam2);
  }

  /// Calculate probability summary of outcomes
  Map<String, dynamic> _calculateOutcomeProbabilities(
    List<SimulationEvent> events,
    Map<String, BattlePokemon> finalStates,
  ) {
    final probabilities = <String, dynamic>{};

    // Count KOs
    int koCount = 0;
    for (final event in events) {
      if (event.type == SimulationEventType.summary &&
          event.message.contains('fainted')) {
        koCount++;
      }
    }

    if (koCount > 0) {
      probabilities['knockoutsOccurred'] = koCount;
    }

    // HP ranges for each pokemon
    for (final entry in finalStates.entries) {
      probabilities['${entry.value.pokemonName}_hp_percent'] =
          (entry.value.currentHp / entry.value.maxHp) * 100;
    }

    return probabilities;
  }

  /// Create a deep copy of a BattlePokemon to avoid mutations
  BattlePokemon _copyPokemon(BattlePokemon original) {
    return original.copyWith(
      statStages: Map.from(original.statStages),
    );
  }

  /// Determine the number of targets based on the target string
  int _determineTargetCount(
    String? targetName,
    List<BattlePokemon> team1Active,
    List<BattlePokemon> team2Active,
  ) {
    if (targetName == null) return 1;

    // Check for multi-target indicators
    switch (targetName) {
      case 'all-opposing':
        // Count all active opponents (typically 1-2 in singles/doubles)
        return team2Active.where((p) => p.currentHp > 0).length.clamp(1, 2);
      case 'all-field':
        // Count all active pokemon on field
        final allActive = [...team1Active, ...team2Active];
        return allActive.where((p) => p.currentHp > 0).length.clamp(1, 4);
      case 'all-team':
      case 'all-except-user':
        // Count all team members (typically 1-2 in singles/doubles)
        return team1Active.where((p) => p.currentHp > 0).length.clamp(1, 2);
      default:
        // Single target (includes specific pokemon names)
        return 1;
    }
  }
}
