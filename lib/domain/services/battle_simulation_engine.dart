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
  late final DamageCalculator _damageCalculator;

  BattleSimulationEngine({
    required this.moveDatabase,
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

          // TODO: Apply to all opponents, not just one
          // Handle abilities on entry
          final opponent = _getFirstActiveOpponent(switchedInPokemon,
              finalStates, currentFieldTeam1, currentFieldTeam2);
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
      if (pokemon == null || pokemon.currentHp <= 0) {
        continue; // Pokemon is fainted
      }

      if (turnAction.action is AttackAction) {
        final attackAction = turnAction.action as AttackAction;
        final moveData = moveDatabase[attackAction.moveName];

        if (moveData != null) {
          // Find the defender based on the target name or slot
          // For multi-target moves, override the target to hit all opposing Pokémon
          String? targetName = attackAction.targetPokemonName;
          if (moveData.targets != null && 
              moveData.targets!.toLowerCase().contains('all adjacent foes')) {
            targetName = 'all-opposing';
          }
          
          final defenders = _findDefenders(
            targetName,
            pokemon,
            finalStates,
            currentFieldTeam1,
            currentFieldTeam2,
          );

          events.addAll(_executeMove(
            attacker: pokemon,
            defenders: defenders,
            currentFieldTeam1: currentFieldTeam1,
            currentFieldTeam2: currentFieldTeam2,
            move: moveData,
            fieldConditions: fieldConditions,
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

                final opponent = _getFirstActiveOpponent(switchedInPokemon,
                    finalStates, currentFieldTeam1, currentFieldTeam2);
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
    required List<BattlePokemon> defenders,
    required List<BattlePokemon> currentFieldTeam1,
    required List<BattlePokemon> currentFieldTeam2,
    required Move move,
    required Map<String, dynamic> fieldConditions,
  }) {
    final events = <SimulationEvent>[];

    // Log move usage
    events.add(SimulationEvent(
      message: '${attacker.pokemonName} used ${move.name}!',
      type: SimulationEventType.move,
      affectedPokemonName: attacker.originalName,
    ));

    for (final defender in defenders) {
      // Check if move hits
      final isProtected = _isProtected(
          attacker,
          defender,
          defenders,
          currentFieldTeam1,
          currentFieldTeam2,
          move,
          fieldConditions['trickRoom'] == true);

      final damageResult = _damageCalculator.calculateDamage(
          attacker: attacker,
          defender: defender,
          move: move,
          attackerTypes: attacker.types,
          defenderTypes: defender.types,
          targetCount: defenders.length,
          // TODO: Add extra params
          moveProperties: MoveProperties(
            isProtected: isProtected,
            isZMove: false,
            isDynamaxMove: false,
            isParentalBondSecondHit: false,
          ),
          fieldState: FieldState());

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
      if (damageResult.isDamageBlocked) {
        var message = '${defender.pokemonName} was protected!';
        events.add(SimulationEvent(
          message: message,
          type: SimulationEventType.damage,
          affectedPokemonName: defender.originalName,
          damageAmount: 0,
          hpBefore: defender.currentHp,
          hpAfter: defender.currentHp,
        ));
      } else if (damageResult.maxDamage > 0) {
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
    }

    return events;
  }

  /// Get the opponent of a given pokemon
  BattlePokemon? _getFirstActiveOpponent(
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
  List<BattlePokemon> _findDefenders(
    String? targetName,
    BattlePokemon attacker,
    Map<String, BattlePokemon> allStates,
    List<BattlePokemon> currentFieldTeam1,
    List<BattlePokemon> currentFieldTeam2,
  ) {
    List<BattlePokemon> defenders = [];
    if (targetName == null) {
      // No specific target, use first active opponent
      BattlePokemon? opponent = _getFirstActiveOpponent(
          attacker, allStates, currentFieldTeam1, currentFieldTeam2);
      if (opponent != null) {
        defenders.add(opponent);
      }
      return defenders;
    }

    // Handle multi-target special cases
    if (targetName == 'all-opposing') {
      final isTeam1 =
          currentFieldTeam1.any((p) => p.originalName == attacker.originalName);
      final opposingTeam = isTeam1 ? currentFieldTeam2 : currentFieldTeam1;
      return opposingTeam.where((p) => p.currentHp > 0).toList();
    } else if (targetName == 'all-field') {
      final allField = [...currentFieldTeam1, ...currentFieldTeam2];
      return allField.where((p) => p.currentHp > 0).toList();
    } else if (targetName == 'all-team') {
      final isTeam1 =
          currentFieldTeam1.any((p) => p.originalName == attacker.originalName);
      final ownTeam = isTeam1 ? currentFieldTeam1 : currentFieldTeam2;
      return ownTeam.where((p) => p.currentHp > 0).toList();
    } else if (targetName == 'all-except-user') {
      // For multi-target, return first opponent (actual damage will be handled separately)
      final allField = [...currentFieldTeam1, ...currentFieldTeam2];
      return allField
          .where(
              (p) => p.originalName != attacker.originalName && p.currentHp > 0)
          .toList();
    }

    // Try to find the specific pokemon by name in the current field
    // final isTeam1 =
    //     currentFieldTeam1.any((p) => p.originalName == attacker.originalName);
    // final opponentField = isTeam1 ? currentFieldTeam2 : currentFieldTeam1;
    final combinedField = [...currentFieldTeam1, ...currentFieldTeam2];

    for (final pokemon in combinedField) {
      if (pokemon.pokemonName == targetName ||
          pokemon.originalName == targetName) {
        final state = allStates[pokemon.originalName];
        if (state != null && state.currentHp > 0) {
          defenders.add(state);
          return defenders;
        }
      }
    }

    // If specific pokemon not found in opponent field, return first active opponent
    BattlePokemon? opponent = _getFirstActiveOpponent(
        attacker, allStates, currentFieldTeam1, currentFieldTeam2);
    if (opponent != null) {
      defenders.add(opponent);
    }
    return defenders;
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

  /// Check whether the defender is protected from the attacking move by itself or any other defender
  bool _isProtected(
      BattlePokemon attacker,
      BattlePokemon defender,
      List<BattlePokemon> defenders,
      List<BattlePokemon> currentFieldTeam1,
      List<BattlePokemon> currentFieldTeam2,
      Move move,
      bool isTrickRoomActive) {
    // Check wide guard spread protection first (cover ally switching in usecase)
    final attackerIsTeam1 =
        currentFieldTeam1.any((p) => p.originalName == attacker.originalName);
    final attackerTeam =
        attackerIsTeam1 ? currentFieldTeam1 : currentFieldTeam2;
    final defenderIsTeam1 =
        currentFieldTeam1.any((p) => p.originalName == defender.originalName);
    final defenderTeam =
        defenderIsTeam1 ? currentFieldTeam1 : currentFieldTeam2;
    final allyAttackActions = [for (var ally in defenderTeam) ally.queuedAction]
        .whereType<AttackAction>()
        .toList();
    final allyAttackNames =
        [for (var action in allyAttackActions) action.moveName].toList();
    final allyDefenders = defenders.where((p) => defenderTeam.contains(p));
    if (allyAttackNames.contains("Wide Guard") &&
        attackerTeam != defenderTeam &&
        allyDefenders.length > 1) {
      return true;
    }

    // Standard protecting moves
    final protectingMoves = [
      "Baneful Bunker",
      "Burning Bulwark",
      "Detect",
      "King's Shield",
      "Mat Block",
      "Max Guard",
      "Obstruct",
      "Protect",
      "Silk Trap",
      "Spiky Shield"
    ];

    final defenderAction = defender.queuedAction;
    if (defenderAction is! AttackAction) {
      return false;
    }

    // Quick guard is priority +3
    if (move.priority > 0 &&
        move.priority < 4 &&
        defenderAction.moveName == "Quick Guard") {
      // If priority == 3, compare defender speeds
      if (move.priority == 3) {
        // TODO: if attack has same priority as quick guard, defender must be moving first to be protected
        return true;
      }
      return true;
    }

    // If move is a status move, check Crafty Shield
    if (move.category.toLowerCase() == "status" &&
        (defenderAction.moveName == "Crafty Shield" ||
            allyAttackNames.contains("Crafty Shield"))) {
      return true;
    }

    //  Otherwise check if protecting self
    return protectingMoves.contains(defenderAction.moveName);
  }
}
