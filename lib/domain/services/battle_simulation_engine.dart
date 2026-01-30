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
  final Map<String, dynamic> probabilities; // outcome -> probability

  TurnOutcome({
    required this.events,
    required this.finalStates,
    required this.probabilities,
  });
}

/// Main battle simulation engine that processes a full turn
class BattleSimulationEngine {
  final Map<String, dynamic> moveDatabase; // move name -> Move
  final Map<String, List<String>> pokemonTypesMap; // pokemon name -> types

  BattleSimulationEngine({
    required this.moveDatabase,
    required this.pokemonTypesMap,
  });

  /// Process a complete turn of battle
  ///
  /// Returns all events that occurred during the turn and final battle state
  TurnOutcome processTurn({
    required List<BattlePokemon> team1Active,
    required List<BattlePokemon> team2Active,
    required Map<String, BattleAction> actionsMap, // pokemonName -> action
    required Map<String, dynamic> fieldConditions,
  }) {
    final events = <SimulationEvent>[];
    final finalStates = <String, BattlePokemon>{};

    // Copy pokemon states to avoid mutations
    final allPokemon = <BattlePokemon>[...team1Active, ...team2Active];
    for (final p in allPokemon) {
      finalStates[p.originalName] = _copyPokemon(p);
    }

    // Step 1: Handle abilities on entry (switches)
    // TODO: Track which pokemon were just switched in
    final switchedInPokemon = _identifySwitches(actionsMap);
    for (final pokemonName in switchedInPokemon) {
      final pokemon = finalStates[pokemonName];
      if (pokemon != null) {
        final opponent =
            _getOpponent(pokemon, finalStates, team1Active, team2Active);
        events.addAll(
          AbilityEffectProcessor.processSwitchInAbility(pokemon, opponent),
        );
      }
    }

    // Step 2: Calculate turn order
    final isTrickRoomActive = fieldConditions['trickRoom'] == true;
    final turnActions = TurnOrderCalculator.calculateTurnOrder(
      allActivePokemon: allPokemon,
      actionsMap: actionsMap,
      moveDatabase: moveDatabase,
      isTrickRoomActive: isTrickRoomActive,
      isChildsPlayActive: false, // TODO: implement
    );

    // Step 3: Execute actions in turn order
    for (final turnAction in turnActions) {
      final pokemon = finalStates[turnAction.pokemon.originalName];
      if (pokemon == null || pokemon.currentHp <= 0)
        continue; // Pokemon is fainted

      final opponent =
          _getOpponent(pokemon, finalStates, team1Active, team2Active);

      if (turnAction.action is AttackAction) {
        final attackAction = turnAction.action as AttackAction;
        final moveData = moveDatabase[attackAction.moveName];

        if (moveData != null && opponent != null) {
          events.addAll(_executeMove(
            attacker: pokemon,
            defender: opponent,
            move: moveData,
            fieldConditions: fieldConditions,
          ));
        }
      } else if (turnAction.action is SwitchAction) {
        // Switches are handled separately
        // For now, just log
        events.add(SimulationEvent(
          message: '${pokemon.pokemonName} switched out!',
          type: SimulationEventType.summary,
        ));
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
      probabilities: probabilities,
    );
  }

  /// Execute a move and return all events that occur
  List<SimulationEvent> _executeMove({
    required BattlePokemon attacker,
    required BattlePokemon defender,
    required Move move,
    required Map<String, dynamic> fieldConditions,
  }) {
    final events = <SimulationEvent>[];

    // Check if move hits
    final damageResult = DamageCalculator.calculateDamage(
      attacker: attacker,
      defender: defender,
      move: move,
      attackerTypes: pokemonTypesMap[attacker.pokemonName] ?? ['Normal'],
      defenderTypes: pokemonTypesMap[defender.pokemonName] ?? ['Normal'],
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

      var message = '${defender.pokemonName} took $damageDealt damage!';

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
      move.category ?? 'Status',
      damageResult.maxDamage > 0,
      damageResult.averageDamage,
    ));

    return events;
  }

  /// Identify which pokemon were switched in this turn
  Set<String> _identifySwitches(Map<String, BattleAction> actionsMap) {
    final switched = <String>{};
    for (final entry in actionsMap.entries) {
      if (entry.value is SwitchAction) {
        switched.add((entry.value as SwitchAction).targetPokemonName);
      }
    }
    return switched;
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
}
