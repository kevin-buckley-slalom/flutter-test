import 'dart:math';

import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/domain/services/turn_order_calculator.dart';
import 'package:championdex/domain/services/damage_calculator.dart';
import 'package:championdex/domain/services/ability_effect_processor.dart';
import 'package:championdex/domain/services/item_effect_processor.dart';
import 'package:championdex/domain/battle/simulation_event.dart';
import 'package:uuid/uuid.dart';

/// Tracks active screens for a team (Light Screen, Reflect, Aurora Veil)
class ScreenState {
  int lightScreenTurns = 0;
  int reflectTurns = 0;
  int auroraVeilTurns = 0;

  bool get hasLightScreen => lightScreenTurns > 0;
  bool get hasReflect => reflectTurns > 0;
  bool get hasAuroraVeil => auroraVeilTurns > 0;

  void decrementTurns() {
    if (lightScreenTurns > 0) lightScreenTurns--;
    if (reflectTurns > 0) reflectTurns--;
    if (auroraVeilTurns > 0) auroraVeilTurns--;
  }

  void reset() {
    lightScreenTurns = 0;
    reflectTurns = 0;
    auroraVeilTurns = 0;
  }
}

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
  final _uuid = const Uuid();
  final _random = Random();

  BattleSimulationEngine({
    required this.moveDatabase,
  }) {
    _damageCalculator = DamageCalculator();
  }

  /// Redirection state tracking
  /// Maps team ('team1' or 'team2') to the pokemon currently redirecting attacks
  final Map<String, BattlePokemon?> _activeRedirections = {
    'team1': null,
    'team2': null,
  };

  /// Screen state tracking for both teams
  /// Tracks Light Screen, Reflect, and Aurora Veil with turns remaining
  final Map<String, ScreenState> _screenStates = {
    'team1': ScreenState(),
    'team2': ScreenState(),
  };

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
    Map<String, Map<String, dynamic>>?
        forcedEffects, // pokemonName -> {effectName, value}
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

    // Apply any forced effects after copying
    if (forcedEffects != null) {
      for (final entry in forcedEffects.entries) {
        final pokemonName = entry.key;
        final effects = entry.value;
        final pokemon = finalStates[pokemonName];
        if (pokemon != null) {
          for (final effectEntry in effects.entries) {
            final effectName = effectEntry.key;
            final effectValue = effectEntry.value;
            pokemon.volatileStatus[effectName] = effectValue;
          }
        }
      }
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
          id: _uuid.v4(),
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
            id: _uuid.v4(),
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

    // Step 3: Reset redirection state and decrement screen durations at start of turn
    _activeRedirections['team1'] = null;
    _activeRedirections['team2'] = null;

    // Decrement existing screen durations
    _screenStates['team1']!.decrementTurns();
    _screenStates['team2']!.decrementTurns();

    // Step 4: Execute moves with dynamic turn order recalculation
    // Track which pokemon have already moved this turn
    final movedPokemon = <String>{};

    while (movedPokemon.length < moveActions.length) {
      // Recalculate turn order for remaining actions (Gen 8+ mechanic)
      final remainingActions = moveActions
          .where(
              (action) => !movedPokemon.contains(action.pokemon.originalName))
          .toList();

      if (remainingActions.isEmpty) break;

      // Recalculate order based on current speeds
      final remainingActionsMap = <String, BattleAction>{};
      for (final action in remainingActions) {
        remainingActionsMap[action.pokemon.originalName] = action.action;
      }

      final recalculatedOrder = TurnOrderCalculator.calculateTurnOrder(
        allActivePokemon: remainingActions
            .map((a) => finalStates[a.pokemon.originalName]!)
            .toList(),
        actionsMap: remainingActionsMap,
        moveDatabase: moveDatabase,
        isTrickRoomActive: isTrickRoomActive,
        isChildsPlayActive: false,
      );

      if (recalculatedOrder.isEmpty) break;

      // Execute the next action in the recalculated order
      final turnAction = recalculatedOrder.first;
      final pokemon = finalStates[turnAction.pokemon.originalName];

      if (pokemon == null || pokemon.currentHp <= 0) {
        movedPokemon.add(turnAction.pokemon.originalName);
        continue; // Pokemon is fainted
      }

      movedPokemon.add(pokemon.originalName);

      if (turnAction.action is AttackAction) {
        final attackAction = turnAction.action as AttackAction;
        final moveData = moveDatabase[attackAction.moveName];

        if (moveData != null) {
          // Check if pokemon is asleep and prevent move execution
          if (pokemon.status?.toLowerCase() == 'sleep') {
            // 50% chance to wake up each turn (simplified for deterministic sim)
            events.add(SimulationEvent(
              id: _uuid.v4(),
              message: '${pokemon.pokemonName} is fast asleep and cannot move!',
              type: SimulationEventType.summary,
              affectedPokemonName: pokemon.originalName,
            ));
            continue; // Skip this move
          }

          // Check if pokemon is frozen and prevent move execution
          if (pokemon.status?.toLowerCase() == 'freeze') {
            events.add(SimulationEvent(
              id: _uuid.v4(),
              message: '${pokemon.pokemonName} is frozen solid!',
              type: SimulationEventType.summary,
              affectedPokemonName: pokemon.originalName,
            ));
            continue; // Skip this move
          }

          // Check if pokemon is flinched and prevent move execution
          if (pokemon.volatileStatus['flinch'] == true) {
            events.add(SimulationEvent(
              id: _uuid.v4(),
              message: '${pokemon.pokemonName} flinched and cannot move!',
              type: SimulationEventType.summary,
              affectedPokemonName: pokemon.originalName,
            ));
            // Remove flinch status after the turn
            pokemon.volatileStatus['flinch'] = false;
            continue; // Skip this move
          }

          // Check if pokemon is confused and may hit itself
          if (pokemon.volatileStatus['confused'] == true) {
            final turnsRemaining =
                pokemon.volatileStatus['confusion_turns_remaining'] as int?;

            // Check if turns remain (don't decrement yet - do that after the confusion check)
            if (turnsRemaining != null && turnsRemaining > 0) {
              // Check if this is a rerun where confusion decision was already made
              final confusionDecisionMade =
                  pokemon.volatileStatus['confusion_decision_made'] == true;
              final forceConfusionHit =
                  pokemon.volatileStatus['force_confusion_self_hit'] == true;

              if (confusionDecisionMade) {
                // This is a rerun - don't generate the "is confused..." event
                // since it already exists as the modified event. Just apply the forced behavior.
                pokemon.volatileStatus.remove('confusion_decision_made');
                pokemon.volatileStatus.remove('force_confusion_self_hit');

                if (forceConfusionHit) {
                  // User forced self-hit - apply confusion damage
                  final confusionDamage = _calculateConfusionDamage(pokemon);
                  pokemon.currentHp = (pokemon.currentHp - confusionDamage)
                      .clamp(0, pokemon.maxHp);

                  events.add(SimulationEvent(
                    id: _uuid.v4(),
                    message:
                        '${pokemon.pokemonName} hurt itself in confusion for $confusionDamage damage!',
                    type: SimulationEventType.damageDealt,
                    affectedPokemonName: pokemon.originalName,
                    damageAmount: confusionDamage,
                    isEditable: false,
                  ));

                  continue; // Skip this move due to confusion
                } else {
                  // User forced attack to succeed - fall through to execute move normally
                }
              } else {
                // Normal confusion check - generate the "is confused..." event with toggle
                // Capture state snapshot before confusion self-hit check
                final confusionSnapshot = BattleStateSnapshot.capture(
                  pokemonStates: finalStates,
                  team1Field: currentFieldTeam1,
                  team2Field: currentFieldTeam2,
                  team1Bench: currentBenchTeam1,
                  team2Bench: currentBenchTeam2,
                  fieldConditions: fieldConditions,
                );

                // 33% chance to hit itself in confusion
                final random = DateTime.now().millisecond % 100;
                final hitItself = random < 33;

                // Create the "is confused..." event with toggle
                // If self-hit occurred naturally, mark it so checkbox shows checked
                events.add(SimulationEvent(
                  id: _uuid.v4(),
                  message: '${pokemon.pokemonName} is confused...',
                  type: SimulationEventType.summary,
                  affectedPokemonName: pokemon.originalName,
                  isEditable: true,
                  stateSnapshot: confusionSnapshot,
                  variations: EventVariations(
                    effectProbability: 33.0,
                    effectName: 'confusion_self_hit',
                  ),
                  modification:
                      hitItself ? EventModification(forceEffect: true) : null,
                  isModified: false,
                ));

                if (hitItself) {
                  // Calculate confusion self-damage: 40 BP typeless physical attack
                  final confusionDamage = _calculateConfusionDamage(pokemon);
                  pokemon.currentHp = (pokemon.currentHp - confusionDamage)
                      .clamp(0, pokemon.maxHp);

                  events.add(SimulationEvent(
                    id: _uuid.v4(),
                    message:
                        '${pokemon.pokemonName} hurt itself in confusion for $confusionDamage damage!',
                    type: SimulationEventType.damageDealt,
                    affectedPokemonName: pokemon.originalName,
                    damageAmount: confusionDamage,
                    isEditable: false,
                  ));

                  // Decrement confusion turns after self-hit
                  final newTurns = turnsRemaining - 1;
                  if (newTurns <= 0) {
                    pokemon.volatileStatus.remove('confused');
                    pokemon.volatileStatus.remove('confusion_turns_remaining');
                  } else {
                    pokemon.volatileStatus['confusion_turns_remaining'] =
                        newTurns;
                  }

                  continue; // Skip this move due to confusion
                }

                // Didn't hit itself - decrement turns and continue with move
                final newTurns = turnsRemaining - 1;
                if (newTurns <= 0) {
                  // Confusion will expire at end of turn, but pokemon can still attack now
                  pokemon.volatileStatus.remove('confused');
                  pokemon.volatileStatus.remove('confusion_turns_remaining');
                } else {
                  pokemon.volatileStatus['confusion_turns_remaining'] =
                      newTurns;
                }
                // Fall through to execute move normally
              }
            } else {
              // No turns remaining or no turn tracking - remove confusion and let pokemon act
              pokemon.volatileStatus.remove('confused');
              pokemon.volatileStatus.remove('confusion_turns_remaining');
            }
          }

          // Capture state snapshot before executing move
          final snapshot = BattleStateSnapshot.capture(
            pokemonStates: finalStates,
            team1Field: currentFieldTeam1,
            team2Field: currentFieldTeam2,
            team1Bench: currentBenchTeam1,
            team2Bench: currentBenchTeam2,
            fieldConditions: fieldConditions,
          );

          // Find the defender based on the target name or slot
          // For multi-target moves, override the target to hit all opposing Pokémon
          String? targetName = attackAction.targetPokemonName;
          if (moveData.targets != null &&
              moveData.targets!.toLowerCase().contains('all adjacent foes')) {
            targetName = 'all-opposing';
          }

          // Apply redirection and auto-retargeting
          targetName = _applyRedirection(
            targetName,
            pokemon,
            moveData,
            currentFieldTeam1,
            currentFieldTeam2,
            finalStates,
            events,
          );

          // If targetName is null, move failed due to target being fainted teammate
          if (targetName == null) {
            continue;
          }

          final defenders = _findDefenders(
            targetName,
            pokemon,
            finalStates,
            currentFieldTeam1,
            currentFieldTeam2,
          );

          final moveEvents = _executeMove(
            attacker: pokemon,
            defenders: defenders,
            currentFieldTeam1: currentFieldTeam1,
            currentFieldTeam2: currentFieldTeam2,
            move: moveData,
            fieldConditions: fieldConditions,
            stateSnapshot: snapshot,
            targetName: targetName,
          );
          events.addAll(moveEvents);

          // After successful move execution, check if it was a redirecting move
          // Only set redirection if the pokemon is still alive after using the move
          if (_isRedirectingMove(moveData.name) && pokemon.currentHp > 0) {
            final pokemonIsTeam1 = currentFieldTeam1
                .any((p) => p.originalName == pokemon.originalName);
            final teamKey = pokemonIsTeam1 ? 'team1' : 'team2';
            _activeRedirections[teamKey] = pokemon;

            events.add(SimulationEvent(
              id: _uuid.v4(),
              message: '${pokemon.pokemonName} became the center of attention!',
              type: SimulationEventType.summary,
              affectedPokemonName: pokemon.originalName,
            ));
          }

          // Setup screens after successful move execution
          _setupScreens(pokemon, moveData, currentFieldTeam1, events);

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
                  id: _uuid.v4(),
                  message: '${pokemon.pokemonName} switched out!',
                  type: SimulationEventType.summary,
                ));

                fieldList[slotIndex] = switchedInPokemon;
                benchList.add(pokemon);

                events.add(SimulationEvent(
                  id: _uuid.v4(),
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
    // End of while loop - dynamic turn order recalculation complete

    // Step 5: End of turn effects
    // Passive healing, field damage, etc.
    for (final entry in finalStates.entries) {
      events.addAll(_processDrowsyStatus(entry.value));
      events.addAll(_processStatusConditionEffects(entry.value));
      events.addAll(ItemEffectProcessor.processEndOfTurnItem(entry.value));

      // Clear flinch status at end of turn
      if (entry.value.volatileStatus['flinch'] == true) {
        entry.value.volatileStatus['flinch'] = false;
      }
    }

    // Step 6: Generate outcome summary with probabilities
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

  /// Rerun simulation from a snapshot with an effect forced
  /// This allows toggling probabilistic effects (e.g., force flinch on Air Slash)
  TurnOutcome rerunFromSnapshotWithForcedEffect({
    required BattleStateSnapshot snapshot,
    required SimulationEvent eventToModify,
    required bool forceEffectOccurs,
    required Map<String, BattleAction> actionsMap,
    required Map<String, dynamic> fieldConditions,
  }) {
    // Restore state from snapshot
    final finalStates = <String, BattlePokemon>{};
    for (final entry in snapshot.pokemonStates.entries) {
      finalStates[entry.key] = _copyPokemon(entry.value);
    }

    // Get the modified pokemon that should have the effect applied/removed
    final affectedPokemon = finalStates[eventToModify.affectedPokemonName];
    if (affectedPokemon == null) return _buildOutcomeFromSnapshot(snapshot);

    // Apply or remove the effect based on the toggle
    final effectName = eventToModify.variations?.effectName;
    if (effectName == 'Flinch' && forceEffectOccurs) {
      affectedPokemon.volatileStatus['flinch'] = true;
    } else if (effectName == 'Flinch' && !forceEffectOccurs) {
      affectedPokemon.volatileStatus['flinch'] = false;
    } else if (effectName != null && forceEffectOccurs) {
      // For status conditions like Burn, Paralysis, etc.
      affectedPokemon.status = effectName.toLowerCase();
    } else if (effectName != null && !forceEffectOccurs) {
      // Remove the status condition
      affectedPokemon.status = null;
    }

    // Return the modified outcome
    return _buildOutcomeFromSnapshot(
      BattleStateSnapshot(
        pokemonStates: finalStates,
        team1Field: snapshot.team1Field,
        team2Field: snapshot.team2Field,
        team1Bench: snapshot.team1Bench,
        team2Bench: snapshot.team2Bench,
        fieldConditions: snapshot.fieldConditions,
      ),
    );
  }

  /// Build a turn outcome from a snapshot (used for reruns)
  TurnOutcome _buildOutcomeFromSnapshot(BattleStateSnapshot snapshot) {
    final finalStates = <String, BattlePokemon>{};
    for (final entry in snapshot.pokemonStates.entries) {
      finalStates[entry.key] = _copyPokemon(entry.value);
    }

    return TurnOutcome(
      events: [], // No new events for rerun
      finalStates: finalStates,
      team1FinalField: snapshot.team1Field.map((p) => _copyPokemon(p)).toList(),
      team2FinalField: snapshot.team2Field.map((p) => _copyPokemon(p)).toList(),
      team1FinalBench: snapshot.team1Bench.map((p) => _copyPokemon(p)).toList(),
      team2FinalBench: snapshot.team2Bench.map((p) => _copyPokemon(p)).toList(),
      probabilities: {},
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
    BattleStateSnapshot? stateSnapshot,
    String? targetName,
  }) {
    final events = <SimulationEvent>[];
    final affectedDefenders =
        <BattlePokemon>[]; // Track defenders that were actually hit
    final immuneOrProtectedDefenders =
        <BattlePokemon>[]; // Track defenders that were immune or protected
    final damagedDefenders =
        <BattlePokemon>[]; // Track defenders that took damage

    // Log move usage
    events.add(SimulationEvent(
      id: _uuid.v4(),
      message: '${attacker.pokemonName} used ${move.name}!',
      type: SimulationEventType.moveUsed,
      affectedPokemonName: attacker.originalName,
      sourcePokemonName: attacker.originalName,
      moveName: move.name,
      isEditable: false,
      stateSnapshot: stateSnapshot,
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
          fieldState: _buildFieldState(currentFieldTeam1));

      // Check hit chance
      if (damageResult.hitChance < 1.0) {
        // Calculate if move hits based on probability
        // For now, assume it always hits if probability > 50%
        if (damageResult.hitChance < 0.5) {
          events.add(SimulationEvent(
            id: _uuid.v4(),
            message: '${attacker.pokemonName}\'s attack missed!',
            type: SimulationEventType.missed,
            sourcePokemonName: attacker.originalName,
            affectedPokemonName: defender.originalName,
            moveName: move.name,
            isEditable: true,
            stateSnapshot: stateSnapshot,
            modification: const EventModification(forceMiss: true),
            isModified: false,
            variations: EventVariations(
              hitChance: damageResult.hitChance,
              canMiss: true,
            ),
          ));
          return events;
        }
      }

      // Apply damage
      if (damageResult.isDamageBlocked || damageResult.isTypeImmune) {
        final protectedMessage = '${defender.pokemonName} was protected!';
        final noEffectMessage = 'It has no effect on ${defender.pokemonName}!';
        final message = damageResult.isDamageBlocked
            ? protectedMessage
            : (damageResult.isTypeImmune ? noEffectMessage : ''); // Fallback
        events.add(SimulationEvent(
          id: _uuid.v4(),
          message: message,
          type: SimulationEventType.protected,
          affectedPokemonName: defender.originalName,
          sourcePokemonName: attacker.originalName,
          moveName: move.name,
          damageAmount: 0,
          hpBefore: defender.currentHp,
          hpAfter: defender.currentHp,
          maxHp: defender.maxHp,
          isEditable: false,
        ));
        // Track protected defender
        immuneOrProtectedDefenders.add(defender);
        if (damageResult.isDamageBlocked) {
          _applyProtectionStatusConditionEffects(
            attacker: attacker,
            defender: defender,
            attackerMove: move,
            events: events,
          );
        }
        // Skip this defender for effect application
        continue;
      } else if (damageResult.maxDamage > 0) {
        final damageDealt = damageResult.averageDamage;
        final hpBefore = defender.currentHp;
        defender.currentHp =
            (defender.currentHp - damageDealt).clamp(0, defender.maxHp);
        final hpAfter = defender.currentHp;

        var message =
            '${defender.pokemonName} took $damageDealt damage! (range: ${damageResult.minDamage}-${damageResult.maxDamage})';

        if (damageResult.effectivenessString != null) {
          // Add effectiveness message as separate event
          events.add(SimulationEvent(
            id: _uuid.v4(),
            message: 'It\'s ${damageResult.effectivenessString}!',
            type: SimulationEventType.effectivenessMessage,
            affectedPokemonName: defender.originalName,
            sourcePokemonName: attacker.originalName,
            moveName: move.name,
            isEditable: false,
          ));
        }

        // Defender was actually hit, add to affected list
        affectedDefenders.add(defender);
        damagedDefenders.add(defender);

        // Check if move has probabilistic effects
        final probabilisticEffects = _getProbabilisticEffects(move, defender);

        events.add(SimulationEvent(
          id: _uuid.v4(),
          message: message,
          type: SimulationEventType.damageDealt,
          affectedPokemonName: defender.originalName,
          sourcePokemonName: attacker.originalName,
          moveName: move.name,
          damageAmount: damageDealt,
          hpBefore: hpBefore,
          hpAfter: hpAfter,
          maxHp: defender.maxHp,
          isEditable: true,
          stateSnapshot: stateSnapshot,
          modification: damageResult.isCriticalHit
              ? const EventModification(forceCrit: true)
              : null,
          isModified: false,
          variations: EventVariations(
            damageRolls: damageResult.discreteDamageRolls,
            canCrit: damageResult.isCriticalChance,
            hitChance: damageResult.hitChance,
            canMiss: damageResult.hitChance < 1.0,
            effectiveness: damageResult.effectivenessString != null
                ? (damageResult.effectivenessString == 'super-effective'
                    ? 2.0
                    : damageResult.effectivenessString == 'not very effective'
                        ? 0.5
                        : 1.0)
                : null,
            effectivenessString: damageResult.effectivenessString,
            effectProbability: probabilisticEffects['probability'] as double?,
            effectName: probabilisticEffects['name'] as String?,
          ),
        ));

        // Check for KO
        if (defender.currentHp <= 0) {
          events.add(SimulationEvent(
            id: _uuid.v4(),
            message: '${defender.pokemonName} fainted!',
            type: SimulationEventType.fainted,
            affectedPokemonName: defender.originalName,
            isEditable: false,
          ));
        }

        // Skip secondary and status effects if immune
        if (damageResult.isTypeImmune) {
          immuneOrProtectedDefenders.add(defender);
          continue;
        }
      } else {
        // Status move (no damage) - add to affected list if not protected
        // (Protection was already checked and would have continued earlier)
        affectedDefenders.add(defender);
      }

      // Remove screens if this move breaks barriers (Brick Break, Psychic Fangs, etc.)
      _removeScreens(attacker, move, currentFieldTeam2, events);

      // Item effects after move
      // Item effects after move
      events.addAll(ItemEffectProcessor.processTurnItem(
        attacker,
        move.category,
        damageResult.maxDamage > 0,
        damageResult.averageDamage,
      ));
    }

    _applyStatusConditionEffects(
      attacker: attacker,
      defenders: affectedDefenders,
      damagedDefenders: damagedDefenders,
      immuneOrProtectedDefenders: immuneOrProtectedDefenders,
      currentFieldTeam1: currentFieldTeam1,
      currentFieldTeam2: currentFieldTeam2,
      move: move,
      events: events,
      targetName: targetName,
    );

    // Apply stat change effects only to defenders that were actually hit
    _applyStatChangeEffects(
      attacker: attacker,
      defenders: affectedDefenders,
      immuneOrProtectedDefenders: immuneOrProtectedDefenders,
      currentFieldTeam1: currentFieldTeam1,
      currentFieldTeam2: currentFieldTeam2,
      move: move,
      events: events,
      targetName: targetName,
    );

    // Apply flinch effects
    _applyFlinchEffect(
      attacker: attacker,
      defenders: affectedDefenders,
      damagedDefenders: damagedDefenders,
      immuneOrProtectedDefenders: immuneOrProtectedDefenders,
      currentFieldTeam1: currentFieldTeam1,
      currentFieldTeam2: currentFieldTeam2,
      move: move,
      events: events,
      targetName: targetName,
    );

    // Apply confusion effects
    _applyConfusionEffect(
      attacker: attacker,
      defenders: affectedDefenders,
      damagedDefenders: damagedDefenders,
      immuneOrProtectedDefenders: immuneOrProtectedDefenders,
      currentFieldTeam1: currentFieldTeam1,
      currentFieldTeam2: currentFieldTeam2,
      move: move,
      events: events,
      targetName: targetName,
    );

    return events;
  }

  void _applyStatChangeEffects({
    required BattlePokemon attacker,
    required List<BattlePokemon> defenders,
    required List<BattlePokemon> immuneOrProtectedDefenders,
    required List<BattlePokemon> currentFieldTeam1,
    required List<BattlePokemon> currentFieldTeam2,
    required Move move,
    required List<SimulationEvent> events,
    String? targetName,
  }) {
    final effects = move.structuredEffects;
    if (effects == null || effects.isEmpty) return;

    final attackerIsTeam1 =
        currentFieldTeam1.any((p) => p.originalName == attacker.originalName);
    final allies = attackerIsTeam1 ? currentFieldTeam1 : currentFieldTeam2;
    final opponents = attackerIsTeam1 ? currentFieldTeam2 : currentFieldTeam1;
    final primaryDefender = defenders.isNotEmpty ? defenders.first : null;

    for (final effect in effects) {
      final effectType = effect['type'] as String?;
      if (effectType != 'StatChangeEffect') continue;

      final probability = (effect['probability'] as num?)?.toDouble() ?? 100.0;
      if (probability < 100.0 && _random.nextDouble() * 100 >= probability) {
        continue;
      }

      final statChanges = _extractStatChanges(effect);
      if (statChanges.isEmpty) continue;

      final targets = _resolveStatChangeTargets(
        target: effect['target'] as String?,
        attacker: attacker,
        primaryDefender: primaryDefender,
        allies: allies,
        opponents: opponents,
        affectedDefenders: defenders, // Pass the filtered defenders list
        immuneOrProtectedDefenders: immuneOrProtectedDefenders,
        targetName: targetName,
      );

      for (final target in targets) {
        bool appliedAny = false;
        for (final entry in statChanges.entries) {
          final statKey = entry.key;
          final delta = entry.value;
          if (delta == 0) continue;

          final currentStage = target.statStages[statKey] ?? 0;
          final newStage = (currentStage + delta).clamp(-6, 6);
          target.statStages[statKey] = newStage;

          final direction = delta > 0 ? 'rose' : 'fell';
          final magnitude = delta.abs();
          final stageWord = magnitude == 1 ? 'stage' : 'stages';
          final statName = _displayStatName(statKey);

          events.add(SimulationEvent(
            id: _uuid.v4(),
            message:
                '${target.pokemonName}’s $statName $direction by $magnitude $stageWord!',
            type: SimulationEventType.statChanged,
            affectedPokemonName: target.originalName,
            sourcePokemonName: attacker.originalName,
            moveName: move.name,
            isEditable: false,
          ));
          appliedAny = true;
        }
        if (appliedAny && probability < 100.0) {
          _markProbabilisticEffectOccurred(
            events: events,
            attacker: attacker,
            target: target,
            move: move,
            effectName: 'Stat Change',
          );
        }
      }
    }
  }

  void _applyStatusConditionEffects({
    required BattlePokemon attacker,
    required List<BattlePokemon> defenders,
    required List<BattlePokemon> damagedDefenders,
    required List<BattlePokemon> immuneOrProtectedDefenders,
    required List<BattlePokemon> currentFieldTeam1,
    required List<BattlePokemon> currentFieldTeam2,
    required Move move,
    required List<SimulationEvent> events,
    String? targetName,
  }) {
    final effects = move.structuredEffects;
    if (effects == null || effects.isEmpty) return;

    final statusEffects = effects
        .where((effect) => effect['type'] == 'StatusConditionEffect')
        .toList();
    if (statusEffects.isEmpty) return;

    final attackerIsTeam1 =
        currentFieldTeam1.any((p) => p.originalName == attacker.originalName);
    final allies = attackerIsTeam1 ? currentFieldTeam1 : currentFieldTeam2;
    final opponents = attackerIsTeam1 ? currentFieldTeam2 : currentFieldTeam1;
    final primaryDefender = defenders.isNotEmpty ? defenders.first : null;

    final sharedGroup = statusEffects
        .where((effect) =>
            (effect['note'] as String?)?.toLowerCase().contains('shared') ??
            false)
        .toList();
    final nonShared = statusEffects
        .where((effect) =>
            !((effect['note'] as String?)?.toLowerCase().contains('shared') ??
                false))
        .toList();

    if (sharedGroup.isNotEmpty) {
      final probability =
          (sharedGroup.first['probability'] as num?)?.toDouble() ?? 100.0;
      if (_random.nextDouble() * 100 < probability) {
        final selected = sharedGroup[_random.nextInt(sharedGroup.length)];
        _applySingleStatusConditionEffect(
          effect: selected,
          attacker: attacker,
          defenders: defenders,
          damagedDefenders: damagedDefenders,
          immuneOrProtectedDefenders: immuneOrProtectedDefenders,
          allies: allies,
          opponents: opponents,
          primaryDefender: primaryDefender,
          move: move,
          events: events,
          targetName: targetName,
        );
      }
    }

    for (final effect in nonShared) {
      _applySingleStatusConditionEffect(
        effect: effect,
        attacker: attacker,
        defenders: defenders,
        damagedDefenders: damagedDefenders,
        immuneOrProtectedDefenders: immuneOrProtectedDefenders,
        allies: allies,
        opponents: opponents,
        primaryDefender: primaryDefender,
        move: move,
        events: events,
        targetName: targetName,
      );
    }
  }

  void _applySingleStatusConditionEffect({
    required Map<String, dynamic> effect,
    required BattlePokemon attacker,
    required List<BattlePokemon> defenders,
    required List<BattlePokemon> damagedDefenders,
    required List<BattlePokemon> immuneOrProtectedDefenders,
    required List<BattlePokemon> allies,
    required List<BattlePokemon> opponents,
    required BattlePokemon? primaryDefender,
    required Move move,
    required List<SimulationEvent> events,
    String? targetName,
  }) {
    final probability = (effect['probability'] as num?)?.toDouble() ?? 100.0;
    final probabilityRoll = _random.nextDouble() * 100;
    final effectOccurred =
        probability >= 100.0 || probabilityRoll < probability;

    final timing = (effect['timing'] as String?)?.toLowerCase();
    final condition = effect['condition'] as String?;
    if (condition == null || condition.isEmpty) return;

    final targets = _resolveStatusConditionTargets(
      target: effect['target'] as String?,
      attacker: attacker,
      primaryDefender: primaryDefender,
      allies: allies,
      opponents: opponents,
      affectedDefenders: defenders,
      immuneOrProtectedDefenders: immuneOrProtectedDefenders,
      targetName: targetName,
    );

    for (final target in targets) {
      if (!_passesStatusConditionNote(effect, move, target)) {
        continue;
      }

      if (timing == 'afterdamage' && !damagedDefenders.contains(target)) {
        continue;
      }

      // Only apply if effect occurred (for probabilistic effects)
      if (!effectOccurred && probability < 100.0) {
        continue; // Don't apply if effect didn't occur
      }

      if (_isDrowsyEffect(effect) && condition.toLowerCase() == 'sleep') {
        _applyDrowsyStatus(
          target: target,
          attacker: attacker,
          move: move,
          events: events,
        );
        continue;
      }

      final applied = _tryApplyStatusCondition(
        target: target,
        condition: condition,
        attacker: attacker,
        move: move,
        events: events,
      );
      if (applied && probability < 100.0) {
        _markProbabilisticEffectOccurred(
          events: events,
          attacker: attacker,
          target: target,
          move: move,
          effectName: condition,
        );
      }
    }
  }

  bool _passesStatusConditionNote(
    Map<String, dynamic> effect,
    Move move,
    BattlePokemon target,
  ) {
    final note = (effect['note'] as String?)?.toLowerCase();
    final onContact = effect['onContact'] == true;
    if ((onContact || (note?.contains('contact') ?? false)) &&
        !move.makesContact) {
      return false;
    }

    if (note != null && note.contains('stats boosted')) {
      if (!_hasPositiveStatStage(target)) {
        return false;
      }
    }

    return true;
  }

  bool _isDrowsyEffect(Map<String, dynamic> effect) {
    // Check for explicit delay attributes (Gen 8+ schema)
    final delayTurns = effect['delayTurns'] as int?;
    final appliesToNextTurn = effect['appliesToNextTurn'] as bool?;

    if (delayTurns != null && delayTurns > 0) {
      return true;
    }
    if (appliesToNextTurn == true) {
      return true;
    }

    // Fallback to note-based detection for older data
    final note = (effect['note'] as String?)?.toLowerCase();
    if (note == null) return false;
    return note.contains('drowsy') || note.contains('next turn');
  }

  void _applyDrowsyStatus({
    required BattlePokemon target,
    required BattlePokemon attacker,
    required Move move,
    required List<SimulationEvent> events,
  }) {
    if (target.status != null && target.status != 'none') {
      return;
    }

    if (target.getVolatileStatus('drowsy_turns') != null) {
      return;
    }

    target.setVolatileStatus('drowsy_turns', 2);
    events.add(SimulationEvent(
      id: _uuid.v4(),
      message: '${target.pokemonName} became drowsy!',
      type: SimulationEventType.statusApplied,
      affectedPokemonName: target.originalName,
      sourcePokemonName: attacker.originalName,
      moveName: move.name,
      isEditable: false,
    ));
  }

  bool _hasPositiveStatStage(BattlePokemon target) {
    return target.statStages.values.any((value) => value > 0);
  }

  void _applyProtectionStatusConditionEffects({
    required BattlePokemon attacker,
    required BattlePokemon defender,
    required Move attackerMove,
    required List<SimulationEvent> events,
  }) {
    final defenderAction = defender.queuedAction;
    if (defenderAction is! AttackAction) return;

    final protectionMove = moveDatabase[defenderAction.moveName];
    if (protectionMove == null) return;

    final effects = protectionMove.structuredEffects;
    if (effects == null || effects.isEmpty) return;

    final statusEffects = effects
        .where((effect) => effect['type'] == 'StatusConditionEffect')
        .toList();
    if (statusEffects.isEmpty) return;

    for (final effect in statusEffects) {
      final normalizedTarget = ((effect['target'] as String?) ?? '')
          .replaceAll(RegExp(r'[^a-zA-Z]'), '')
          .toLowerCase();
      if (normalizedTarget != 'attackingopponent' &&
          normalizedTarget != 'attacker') {
        continue;
      }

      final note = (effect['note'] as String?)?.toLowerCase();
      final onContact = effect['onContact'] == true;
      if ((onContact || (note?.contains('contact') ?? false)) &&
          !attackerMove.makesContact) {
        continue;
      }

      // TODO: Handle multi-turn moves like Beak Blast that require phase tracking
      // (e.g., "contact during charging phase"). Once turn states are integrated
      // to support turn-phase tracking, we can determine which phase of a multi-turn
      // move is currently active and apply contact effects accordingly.

      // TODO: Implement multi-turn move tracking for self-confusing moves
      // Moves that confuse the user after 2-3 turns:
      // - Outrage (Dragon, 120 BP, lasts 2-3 turns)
      // - Thrash (Normal, 120 BP, lasts 2-3 turns)
      // - Petal Dance (Grass, 120 BP, lasts 2-3 turns)
      // - Raging Fury (Fire, 120 BP, lasts 2-3 turns)
      // Implementation plan:
      // 1. When one of these moves is used, set pokemon.multiturnMoveName and
      //    pokemon.multiturnMoveTurnsRemaining (random 2-3 turns)
      // 2. Lock the pokemon into using this move on subsequent turns (override action)
      // 3. After the final turn (multiturnMoveTurnsRemaining == 0), apply confusion
      //    using ConfusionEffect with confusesUser = true
      // 4. Clear multiturnMoveName and multiturnMoveTurnsRemaining

      final probability = (effect['probability'] as num?)?.toDouble() ?? 100.0;
      if (probability < 100.0 && _random.nextDouble() * 100 >= probability) {
        continue;
      }

      final condition = effect['condition'] as String?;
      if (condition == null || condition.isEmpty) continue;

      _tryApplyStatusCondition(
        target: attacker,
        condition: condition,
        attacker: defender,
        move: protectionMove,
        events: events,
      );
    }
  }

  bool _tryApplyStatusCondition({
    required BattlePokemon target,
    required String condition,
    required BattlePokemon attacker,
    required Move move,
    required List<SimulationEvent> events,
  }) {
    final normalizedCondition = _normalizeStatusCondition(condition);
    if (!_canApplyStatusCondition(target, normalizedCondition)) {
      return false;
    }

    if (target.status != null && target.status != 'none') {
      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${target.pokemonName} is already ${target.status}!',
        type: SimulationEventType.statusApplied,
        affectedPokemonName: target.originalName,
        sourcePokemonName: attacker.originalName,
        moveName: move.name,
        isEditable: false,
      ));
      return false;
    }

    target.status = normalizedCondition;
    events.add(SimulationEvent(
      id: _uuid.v4(),
      message:
          '${target.pokemonName} was ${_statusMessage(normalizedCondition)}!',
      type: SimulationEventType.statusApplied,
      affectedPokemonName: target.originalName,
      sourcePokemonName: attacker.originalName,
      moveName: move.name,
      isEditable: false,
    ));
    return true;
  }

  String _normalizeStatusCondition(String condition) {
    switch (condition.toLowerCase()) {
      case 'toxic':
        return 'badPoison';
      default:
        return condition;
    }
  }

  bool _canApplyStatusCondition(BattlePokemon target, String condition) {
    final typesLower = target.types.map((t) => t.toLowerCase()).toList();
    final ability = target.ability.toLowerCase();

    switch (condition.toLowerCase()) {
      case 'burn':
        if (typesLower.contains('fire')) return false;
        if (ability == 'water veil' || ability == 'water bubble') return false;
        return true;
      case 'freeze':
        if (typesLower.contains('ice')) return false;
        if (ability == 'magma armor') return false;
        return true;
      case 'paralysis':
        if (typesLower.contains('electric')) return false;
        if (ability == 'limber') return false;
        return true;
      case 'poison':
      case 'badpoison':
        if (typesLower.contains('poison') || typesLower.contains('steel')) {
          return false;
        }
        if (ability == 'immunity' || ability == 'pastel veil') return false;
        return true;
      case 'sleep':
        if (ability == 'insomnia' ||
            ability == 'vital spirit' ||
            ability == 'sweet veil') {
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  String _statusMessage(String condition) {
    switch (condition.toLowerCase()) {
      case 'burn':
        return 'burned';
      case 'paralysis':
        return 'paralyzed';
      case 'poison':
        return 'poisoned';
      case 'badpoison':
        return 'badly poisoned';
      case 'sleep':
        return 'put to sleep';
      case 'freeze':
        return 'frozen';
      default:
        return condition;
    }
  }

  /// Get the first probabilistic effect from a move (if any)
  /// Returns a map with 'probability' and 'name' keys
  Map<String, dynamic> _getProbabilisticEffects(
      Move move, BattlePokemon defender) {
    final effects = move.structuredEffects;
    if (effects == null || effects.isEmpty) return {};

    for (final effect in effects) {
      final probability = (effect['probability'] as num?)?.toDouble() ?? 100.0;

      // Only return effects with probability < 100
      if (probability < 100.0) {
        final effectType = effect['type'] as String?;

        if (effectType == 'FlinchEffect') {
          return {
            'probability': probability,
            'name': 'Flinch',
          };
        } else if (effectType == 'StatusConditionEffect') {
          final condition = effect['condition'] as String?;
          if (condition != null) {
            return {
              'probability': probability,
              'name': condition,
            };
          }
        } else if (effectType == 'StatChangeEffect') {
          return {
            'probability': probability,
            'name': 'Stat Change',
          };
        }
      }
    }

    return {};
  }

  /// Apply flinch effect to defenders (prevents them from attacking)
  void _applyFlinchEffect({
    required BattlePokemon attacker,
    required List<BattlePokemon> defenders,
    required List<BattlePokemon> damagedDefenders,
    required List<BattlePokemon> immuneOrProtectedDefenders,
    required List<BattlePokemon> currentFieldTeam1,
    required List<BattlePokemon> currentFieldTeam2,
    required Move move,
    required List<SimulationEvent> events,
    String? targetName,
  }) {
    final effects = move.structuredEffects;
    if (effects == null || effects.isEmpty) return;

    final flinchEffects =
        effects.where((effect) => effect['type'] == 'FlinchEffect').toList();
    if (flinchEffects.isEmpty) return;

    final attackerIsTeam1 =
        currentFieldTeam1.any((p) => p.originalName == attacker.originalName);
    final opponents = attackerIsTeam1 ? currentFieldTeam2 : currentFieldTeam1;
    final primaryDefender = defenders.isNotEmpty ? defenders.first : null;

    for (final effect in flinchEffects) {
      _applySingleFlinchEffect(
        effect: effect,
        attacker: attacker,
        defenders: defenders,
        damagedDefenders: damagedDefenders,
        immuneOrProtectedDefenders: immuneOrProtectedDefenders,
        opponents: opponents,
        primaryDefender: primaryDefender,
        move: move,
        events: events,
        targetName: targetName,
      );
    }
  }

  void _applySingleFlinchEffect({
    required Map<String, dynamic> effect,
    required BattlePokemon attacker,
    required List<BattlePokemon> defenders,
    required List<BattlePokemon> damagedDefenders,
    required List<BattlePokemon> immuneOrProtectedDefenders,
    required List<BattlePokemon> opponents,
    required BattlePokemon? primaryDefender,
    required Move move,
    required List<SimulationEvent> events,
    String? targetName,
  }) {
    final probability = (effect['probability'] as num?)?.toDouble() ?? 100.0;
    final probabilityRoll = _random.nextDouble() * 100;
    final effectOccurred =
        probability >= 100.0 || probabilityRoll < probability;

    // Resolve targets for the flinch effect
    final targets = _resolveFlinchTargets(
      target: effect['target'] as String?,
      primaryDefender: primaryDefender,
      opponents: opponents,
      affectedDefenders: defenders,
      immuneOrProtectedDefenders: immuneOrProtectedDefenders,
      targetName: targetName,
    );

    final timing = (effect['timing'] as String?)?.toLowerCase();
    final note = (effect['note'] as String?)?.toLowerCase();

    for (final target in targets) {
      // Check if flinch can be applied based on conditions
      if (!_canApplyFlinch(effect, move, target, timing, note)) {
        continue;
      }

      // Apply flinch to target if effect occurred
      if (effectOccurred) {
        target.volatileStatus['flinch'] = true;
        _markEffectOnDamageEvent(
          events: events,
          attackerName: attacker.originalName,
          targetName: target.originalName,
          moveName: move.name,
          effectName: 'Flinch',
        );
      }

      // Message will be shown when the pokemon attempts to move and is prevented by flinch
    }
  }

  void _markProbabilisticEffectOccurred({
    required List<SimulationEvent> events,
    required BattlePokemon attacker,
    required BattlePokemon target,
    required Move move,
    required String effectName,
  }) {
    _markEffectOnDamageEvent(
      events: events,
      attackerName: attacker.originalName,
      targetName: target.originalName,
      moveName: move.name,
      effectName: effectName,
    );
  }

  void _markEffectOnDamageEvent({
    required List<SimulationEvent> events,
    required String attackerName,
    required String targetName,
    required String moveName,
    required String effectName,
  }) {
    for (int i = events.length - 1; i >= 0; i--) {
      final event = events[i];
      if (event.type == SimulationEventType.damageDealt &&
          event.sourcePokemonName == attackerName &&
          event.affectedPokemonName == targetName &&
          event.moveName == moveName &&
          event.variations?.effectName == effectName &&
          event.variations?.effectProbability != null) {
        final updatedModification =
            (event.modification ?? const EventModification())
                .copyWith(forceEffect: true);
        events[i] = event.copyWith(
          modification: updatedModification,
          isModified: false,
        );
        break;
      }
    }
  }

  /// Resolve which pokemon should receive the flinch effect
  List<BattlePokemon> _resolveFlinchTargets({
    required String? target,
    required BattlePokemon? primaryDefender,
    required List<BattlePokemon> opponents,
    required List<BattlePokemon> affectedDefenders,
    required List<BattlePokemon> immuneOrProtectedDefenders,
    String? targetName,
  }) {
    final normalizedTarget = target?.toLowerCase() ?? 'normal';

    switch (normalizedTarget) {
      case 'users_side':
      case 'user':
      case 'ally':
        return []; // Not used for flinch

      case 'single':
      case 'normal':
        if (primaryDefender != null &&
            !immuneOrProtectedDefenders.contains(primaryDefender)) {
          return [primaryDefender];
        }
        return [];

      case 'all':
      case 'all_opponents':
      case 'all_other':
        return affectedDefenders
            .where((d) => !immuneOrProtectedDefenders.contains(d))
            .toList();

      case 'self':
        return []; // Not used for flinch

      default:
        // Default to primary defender if target not recognized
        if (primaryDefender != null &&
            !immuneOrProtectedDefenders.contains(primaryDefender)) {
          return [primaryDefender];
        }
        return [];
    }
  }

  /// Check if flinch can be applied based on special conditions and abilities
  bool _canApplyFlinch(
    Map<String, dynamic> effect,
    Move move,
    BattlePokemon target,
    String? timing,
    String? note,
  ) {
    final abilityLower = target.ability.toLowerCase();

    // Inner Focus prevents flinch
    if (abilityLower == 'inner focus') {
      return false;
    }

    // Flinch cannot be applied to targets that already have flinch
    if (target.volatileStatus['flinch'] == true) {
      return false;
    }

    // Fake Out: only works on first turn (turn counter would be tracked in the engine state)
    // For now, we'll assume this is handled by the move's availability logic
    // (Fake Out can only be used on the first turn of battle)

    // Focus Punch: only applies flinch if the user was hit before attacking
    // This would be tracked in the attacker's volatileStatus (hit_before_move)

    // Upper Hand: only if opponent chose priority move
    // This would be tracked based on opponent's move selection

    // Sky Attack: timing is afterDamage (checked in main application logic)

    // Check if there's a note specifying special conditions
    if (note != null) {
      if (note.contains('user hit before moving')) {
        // Check if attacker has 'hit_before_move' volatile status
        if (effect['attacker'] == null) {
          // Attacker data not available in effect, can't check
          return true; // Allow it for now
        }
      }

      if (note.contains('target chose priority')) {
        // Would need target's move choice to verify
        // For now, allow it
        return true;
      }
    }

    return true;
  }

  /// Apply confusion effect to defenders
  void _applyConfusionEffect({
    required BattlePokemon attacker,
    required List<BattlePokemon> defenders,
    required List<BattlePokemon> damagedDefenders,
    required List<BattlePokemon> immuneOrProtectedDefenders,
    required List<BattlePokemon> currentFieldTeam1,
    required List<BattlePokemon> currentFieldTeam2,
    required Move move,
    required List<SimulationEvent> events,
    String? targetName,
  }) {
    final effects = move.structuredEffects;
    if (effects == null || effects.isEmpty) return;

    final confusionEffects =
        effects.where((effect) => effect['type'] == 'ConfusionEffect').toList();
    if (confusionEffects.isEmpty) return;

    final attackerIsTeam1 =
        currentFieldTeam1.any((p) => p.originalName == attacker.originalName);
    final opponents = attackerIsTeam1 ? currentFieldTeam2 : currentFieldTeam1;
    final primaryDefender = defenders.isNotEmpty ? defenders.first : null;

    for (final effect in confusionEffects) {
      _applySingleConfusionEffect(
        effect: effect,
        attacker: attacker,
        defenders: defenders,
        damagedDefenders: damagedDefenders,
        immuneOrProtectedDefenders: immuneOrProtectedDefenders,
        opponents: opponents,
        primaryDefender: primaryDefender,
        move: move,
        events: events,
        targetName: targetName,
      );
    }
  }

  void _applySingleConfusionEffect({
    required Map<String, dynamic> effect,
    required BattlePokemon attacker,
    required List<BattlePokemon> defenders,
    required List<BattlePokemon> damagedDefenders,
    required List<BattlePokemon> immuneOrProtectedDefenders,
    required List<BattlePokemon> opponents,
    required BattlePokemon? primaryDefender,
    required Move move,
    required List<SimulationEvent> events,
    String? targetName,
  }) {
    final probability = (effect['probability'] as num?)?.toDouble() ?? 100.0;
    final probabilityRoll = _random.nextDouble() * 100;
    final effectOccurred =
        probability >= 100.0 || probabilityRoll < probability;

    // Resolve targets for the confusion effect
    final targets = _resolveConfusionTargets(
      target: effect['target'] as String?,
      primaryDefender: primaryDefender,
      opponents: opponents,
      affectedDefenders: defenders,
      immuneOrProtectedDefenders: immuneOrProtectedDefenders,
      attacker: attacker,
      targetName: targetName,
    );

    for (final target in targets) {
      // Check Own Tempo ability
      if (target.ability.toLowerCase() == 'own tempo') {
        events.add(SimulationEvent(
          id: _uuid.v4(),
          message: "${target.pokemonName}'s Own Tempo prevents confusion!",
          type: SimulationEventType.statusApplied,
          affectedPokemonName: target.originalName,
        ));
        continue;
      }

      // Check if already confused
      if (target.volatileStatus['confused'] == true) {
        continue;
      }

      // Apply confusion if effect occurred
      if (effectOccurred) {
        target.volatileStatus['confused'] = true;
        final duration = 1 + (_random.nextInt(4)); // 1-4 turns
        target.volatileStatus['confusion_turns_remaining'] = duration;

        events.add(SimulationEvent(
          id: _uuid.v4(),
          message: '${target.pokemonName} became confused!',
          type: SimulationEventType.statusApplied,
          affectedPokemonName: target.originalName,
          variations: EventVariations(
            effectProbability: probability < 100 ? probability : null,
            effectName: probability < 100 ? 'confusion' : null,
          ),
        ));
      }
    }
  }

  /// Resolve which pokemon should receive the confusion effect
  List<BattlePokemon> _resolveConfusionTargets({
    required String? target,
    required BattlePokemon? primaryDefender,
    required List<BattlePokemon> opponents,
    required List<BattlePokemon> affectedDefenders,
    required List<BattlePokemon> immuneOrProtectedDefenders,
    required BattlePokemon attacker,
    String? targetName,
  }) {
    final normalizedTarget = target?.toLowerCase() ?? 'normal';

    switch (normalizedTarget) {
      case 'user':
      case 'self':
        // Self-confusion (e.g., after multi-turn moves)
        return [attacker];

      case 'opponent':
      case 'single':
      case 'normal':
        if (primaryDefender != null &&
            !immuneOrProtectedDefenders.contains(primaryDefender)) {
          return [primaryDefender];
        }
        return [];

      case 'all':
      case 'all_opponents':
      case 'all_other':
        return affectedDefenders
            .where((d) => !immuneOrProtectedDefenders.contains(d))
            .toList();

      default:
        // Default to primary defender if not protected
        if (primaryDefender != null &&
            !immuneOrProtectedDefenders.contains(primaryDefender)) {
          return [primaryDefender];
        }
        return [];
    }
  }

  Map<String, int> _extractStatChanges(Map<String, dynamic> effect) {
    final changes = <String, int>{};

    final stats = effect['stats'];
    if (stats is Map) {
      for (final entry in stats.entries) {
        final statKey = _normalizeStatStageKey(entry.key.toString());
        final value = (entry.value as num?)?.toInt();
        if (statKey != null && value != null) {
          changes[statKey] = value;
        }
      }
    } else {
      for (final entry in effect.entries) {
        if (_isStatKey(entry.key)) {
          final statKey = _normalizeStatStageKey(entry.key);
          final value = (entry.value as num?)?.toInt();
          if (statKey != null && value != null) {
            changes[statKey] = value;
          }
        }
      }
    }

    return changes;
  }

  bool _isStatKey(String key) {
    const statKeys = {
      'attack',
      'atk',
      'defense',
      'def',
      'spAtk',
      'sp_atk',
      'spa',
      'spDef',
      'sp_def',
      'spd',
      'speed',
      'spe',
      'accuracy',
      'acc',
      'evasion',
      'eva',
    };
    return statKeys.contains(key);
  }

  String? _normalizeStatStageKey(String rawKey) {
    final normalized =
        rawKey.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
    switch (normalized) {
      case 'attack':
      case 'atk':
        return 'atk';
      case 'defense':
      case 'def':
        return 'def';
      case 'spatk':
      case 'specialattack':
      case 'spa':
        return 'spa';
      case 'spdef':
      case 'specialdefense':
      case 'spd':
        return 'spd';
      case 'speed':
      case 'spe':
        return 'spe';
      case 'accuracy':
      case 'acc':
        return 'acc';
      case 'evasion':
      case 'eva':
        return 'eva';
      default:
        return null;
    }
  }

  String _displayStatName(String statKey) {
    switch (statKey) {
      case 'atk':
        return 'Attack';
      case 'def':
        return 'Defense';
      case 'spa':
        return 'Sp. Atk';
      case 'spd':
        return 'Sp. Def';
      case 'spe':
        return 'Speed';
      case 'acc':
        return 'Accuracy';
      case 'eva':
        return 'Evasion';
      default:
        return statKey;
    }
  }

  List<BattlePokemon> _resolveStatusConditionTargets({
    required String? target,
    required BattlePokemon attacker,
    required BattlePokemon? primaryDefender,
    required List<BattlePokemon> allies,
    required List<BattlePokemon> opponents,
    required List<BattlePokemon> affectedDefenders,
    required List<BattlePokemon> immuneOrProtectedDefenders,
    String? targetName,
  }) {
    final normalizedTarget = (target ?? 'opponent')
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toLowerCase();

    List<BattlePokemon> baseTargets;
    switch (normalizedTarget) {
      case 'user':
        return [attacker];
      case 'opponent':
        if (primaryDefender != null) return [primaryDefender];
        baseTargets = affectedDefenders.isNotEmpty
            ? affectedDefenders
            : opponents.where((p) => p.currentHp > 0).toList();
        break;
      case 'ally':
        if (targetName != null) {
          final ally = _findPokemonInListByName(allies, targetName);
          if (ally != null && ally.originalName != attacker.originalName) {
            return [ally];
          }
        }
        return allies
            .where((p) => p.originalName != attacker.originalName)
            .toList();
      case 'allopponents':
      case 'alladjacentopponents':
        baseTargets = affectedDefenders.isNotEmpty
            ? affectedDefenders
            : opponents.where((p) => p.currentHp > 0).toList();
        break;
      case 'allies':
        return allies
            .where((p) => p.originalName != attacker.originalName)
            .toList();
      case 'allteam':
      case 'userteam':
        return allies.where((p) => p.currentHp > 0).toList();
      case 'all':
      case 'allpokemononfield':
        return [...allies, ...opponents].where((p) => p.currentHp > 0).toList();
      default:
        if (primaryDefender != null) return [primaryDefender];
        baseTargets = opponents.where((p) => p.currentHp > 0).toList();
        break;
    }

    return baseTargets
        .where((p) => !immuneOrProtectedDefenders.contains(p))
        .toList();
  }

  List<BattlePokemon> _resolveStatChangeTargets({
    required String? target,
    required BattlePokemon attacker,
    required BattlePokemon? primaryDefender,
    required List<BattlePokemon> allies,
    required List<BattlePokemon> opponents,
    required List<BattlePokemon>
        affectedDefenders, // Defenders that were actually hit
    required List<BattlePokemon>
        immuneOrProtectedDefenders, // Defenders that were immune or protected
    String? targetName,
  }) {
    final normalizedTarget = (target ?? 'opponent')
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toLowerCase();

    switch (normalizedTarget) {
      case 'user':
        return [attacker];
      case 'opponent':
        if (primaryDefender != null) return [primaryDefender];
        // Use affectedDefenders if available, otherwise fall back to opponents
        return affectedDefenders.isNotEmpty
            ? affectedDefenders
            : opponents.where((p) => p.currentHp > 0).toList();
      case 'ally':
        if (targetName != null) {
          final ally = _findPokemonInListByName(allies, targetName);
          if (ally != null && ally.originalName != attacker.originalName) {
            return [ally];
          }
        }
        return allies
            .where((p) => p.originalName != attacker.originalName)
            .toList();
      case 'allopponents':
      case 'alladjacentopponents':
        // For multi-target stat changes, use all opponents EXCEPT those that were immune or protected
        return opponents
            .where((p) =>
                p.currentHp > 0 && !immuneOrProtectedDefenders.contains(p))
            .toList();
      case 'allies':
        return allies
            .where((p) => p.originalName != attacker.originalName)
            .toList();
      case 'allteam':
      case 'userteam':
        return allies.where((p) => p.currentHp > 0).toList();
      case 'all':
      case 'allpokemononfield':
        return [...allies, ...opponents].where((p) => p.currentHp > 0).toList();
      default:
        if (primaryDefender != null) return [primaryDefender];
        return opponents.where((p) => p.currentHp > 0).toList();
    }
  }

  BattlePokemon? _findPokemonInListByName(
    List<BattlePokemon> list,
    String name,
  ) {
    for (final pokemon in list) {
      if (pokemon.pokemonName == name || pokemon.originalName == name) {
        return pokemon;
      }
    }
    return null;
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

  List<SimulationEvent> _processDrowsyStatus(BattlePokemon pokemon) {
    final events = <SimulationEvent>[];
    final turns = pokemon.getVolatileStatus('drowsy_turns');
    if (turns is! int) return events;

    final remaining = turns - 1;
    if (remaining > 0) {
      pokemon.setVolatileStatus('drowsy_turns', remaining);
      return events;
    }

    pokemon.volatileStatus.remove('drowsy_turns');
    if (pokemon.status == null || pokemon.status == 'none') {
      if (_canApplyStatusCondition(pokemon, 'sleep')) {
        pokemon.status = 'sleep';
        events.add(SimulationEvent(
          id: _uuid.v4(),
          message: '${pokemon.pokemonName} fell asleep!',
          type: SimulationEventType.statusApplied,
          affectedPokemonName: pokemon.originalName,
          isEditable: false,
        ));
      }
    }

    return events;
  }

  /// Create a deep copy of a BattlePokemon to avoid mutations
  BattlePokemon _copyPokemon(BattlePokemon original) {
    return original.copyWith(
      statStages: Map.from(original.statStages),
    );
  }

  /// Check if a move redirects attacks to the user
  bool _isRedirectingMove(String moveName) {
    final redirectingMoves = [
      'Follow Me',
      'Rage Powder',
      'Spotlight', // Forces target to be the pokemon Spotlight was used on
    ];
    return redirectingMoves.contains(moveName);
  }

  /// Check if a pokemon has a redirecting ability
  bool _hasRedirectingAbility(BattlePokemon pokemon, String moveType) {
    final abilityLower = pokemon.ability.toLowerCase();

    // Storm Drain redirects Water-type moves
    if (abilityLower == 'storm drain' && moveType.toLowerCase() == 'water') {
      return true;
    }

    // Lightning Rod redirects Electric-type moves
    if (abilityLower == 'lightning rod' &&
        moveType.toLowerCase() == 'electric') {
      return true;
    }

    return false;
  }

  /// Apply redirection to a target if applicable
  /// Returns the potentially redirected target, or null if move should fail
  String? _applyRedirection(
    String? originalTarget,
    BattlePokemon attacker,
    Move move,
    List<BattlePokemon> currentFieldTeam1,
    List<BattlePokemon> currentFieldTeam2,
    Map<String, BattlePokemon> finalStates,
    List<SimulationEvent> events,
  ) {
    // Multi-target moves are not affected by redirection
    if (originalTarget == 'all-opposing' ||
        originalTarget == 'all-field' ||
        originalTarget == 'all-team' ||
        originalTarget == 'all-except-user') {
      return originalTarget;
    }

    // Check if original target is still alive
    final originalTargetPokemon = _findPokemonByName(
      originalTarget,
      currentFieldTeam1,
      currentFieldTeam2,
      finalStates,
    );

    final attackerIsTeam1 =
        currentFieldTeam1.any((p) => p.originalName == attacker.originalName);
    final targetIsTeammate = originalTargetPokemon != null &&
        ((attackerIsTeam1 &&
                currentFieldTeam1.any((p) =>
                    p.originalName == originalTargetPokemon.originalName)) ||
            (!attackerIsTeam1 &&
                currentFieldTeam2.any((p) =>
                    p.originalName == originalTargetPokemon.originalName)));

    // If original target is fainted, handle auto-retargeting
    if (originalTargetPokemon == null || originalTargetPokemon.currentHp <= 0) {
      if (targetIsTeammate) {
        // Teammate fainted → move fails
        events.add(SimulationEvent(
          id: _uuid.v4(),
          message: '${attacker.pokemonName}\'s move failed! Target fainted.',
          type: SimulationEventType.missed,
          sourcePokemonName: attacker.originalName,
        ));
        return null; // Signal move failure
      } else {
        // Opponent fainted → auto-retarget to another opponent
        final opposingTeam =
            attackerIsTeam1 ? currentFieldTeam2 : currentFieldTeam1;
        final availableOpponents =
            opposingTeam.where((p) => p.currentHp > 0).toList();

        if (availableOpponents.isEmpty) {
          events.add(SimulationEvent(
            id: _uuid.v4(),
            message:
                '${attacker.pokemonName}\'s move failed! No valid targets.',
            type: SimulationEventType.missed,
            sourcePokemonName: attacker.originalName,
          ));
          return null;
        }

        // Auto-retarget to first available opponent
        final newTarget = availableOpponents.first;
        events.add(SimulationEvent(
          id: _uuid.v4(),
          message:
              '${attacker.pokemonName}\'s attack was redirected to ${newTarget.pokemonName}!',
          type: SimulationEventType.summary,
          sourcePokemonName: attacker.originalName,
          affectedPokemonName: newTarget.originalName,
        ));
        return newTarget.originalName;
      }
    }

    // Check for active redirection (Follow Me, Rage Powder)
    final teamKey =
        attackerIsTeam1 ? 'team2' : 'team1'; // Redirect from opposing team
    final redirector = _activeRedirections[teamKey];

    if (redirector != null && redirector.currentHp > 0) {
      // Check if move bypasses redirection (e.g., Snipe Shot)
      final bypassesRedirection = move.structuredEffects?.any((effect) {
            return effect['type'] == 'AttackRedirectionBypassEffect' &&
                effect['ignoresMoveRedirection'] == true;
          }) ??
          false;

      if (!bypassesRedirection && !targetIsTeammate) {
        events.add(SimulationEvent(
          id: _uuid.v4(),
          message: '${redirector.pokemonName} drew the attack!',
          type: SimulationEventType.summary,
          affectedPokemonName: redirector.originalName,
        ));
        return redirector.originalName;
      }
    }

    // Check for ability-based redirection (Storm Drain, Lightning Rod)
    if (!targetIsTeammate) {
      final opposingTeam =
          attackerIsTeam1 ? currentFieldTeam2 : currentFieldTeam1;
      for (final potential in opposingTeam) {
        if (potential.currentHp > 0 &&
            potential.originalName != originalTargetPokemon.originalName &&
            _hasRedirectingAbility(potential, move.type)) {
          // Check if move bypasses ability redirection
          final bypassesAbilities = move.structuredEffects?.any((effect) {
                return effect['type'] == 'AttackRedirectionBypassEffect' &&
                    effect['ignoredAbilities'] == true;
              }) ??
              false;

          if (!bypassesAbilities) {
            events.add(SimulationEvent(
              id: _uuid.v4(),
              message:
                  '${potential.pokemonName}\'s ${potential.ability} drew the attack!',
              type: SimulationEventType.summary,
              affectedPokemonName: potential.originalName,
            ));
            return potential.originalName;
          }
        }
      }
    }

    return originalTarget;
  }

  /// Find a pokemon by name across both teams
  BattlePokemon? _findPokemonByName(
    String? name,
    List<BattlePokemon> team1,
    List<BattlePokemon> team2,
    Map<String, BattlePokemon> finalStates,
  ) {
    if (name == null) return null;

    final allPokemon = [...team1, ...team2];
    for (final pokemon in allPokemon) {
      if (pokemon.pokemonName == name || pokemon.originalName == name) {
        return finalStates[pokemon.originalName];
      }
    }
    return null;
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

  /// Setup screens when certain moves are used
  void _setupScreens(
    BattlePokemon attacker,
    Move move,
    List<BattlePokemon> currentFieldTeam1,
    List<SimulationEvent> events,
  ) {
    final pokemonIsTeam1 =
        currentFieldTeam1.any((p) => p.originalName == attacker.originalName);
    final teamKey = pokemonIsTeam1 ? 'team1' : 'team2';
    final screenState = _screenStates[teamKey]!;

    // Check if move has ScreenEffect in structuredEffects
    if (move.structuredEffects == null || move.structuredEffects!.isEmpty) {
      return;
    }

    for (final effect in move.structuredEffects!) {
      final effectType = effect['type'] as String?;
      if (effectType != 'ScreenEffect') {
        continue;
      }

      // Parse screen type
      final screenType = effect['screenType'] as String?;
      final baseDuration = (effect['duration'] as num?)?.toInt() ?? 5;
      int duration = baseDuration;

      // Check for Light Clay extension (extends to 8 turns)
      if (attacker.item?.toLowerCase().contains('light clay') ?? false) {
        duration = 8;
      }

      // Setup the appropriate screen
      if (screenType == 'light-screen') {
        screenState.lightScreenTurns = duration;
        events.add(SimulationEvent(
          id: _uuid.v4(),
          message:
              'Light Screen protects ${pokemonIsTeam1 ? 'Team 1' : 'Team 2'}!',
          type: SimulationEventType.summary,
        ));
      } else if (screenType == 'reflect') {
        screenState.reflectTurns = duration;
        events.add(SimulationEvent(
          id: _uuid.v4(),
          message: 'Reflect protects ${pokemonIsTeam1 ? 'Team 1' : 'Team 2'}!',
          type: SimulationEventType.summary,
        ));
      } else if (screenType == 'aurora-veil') {
        screenState.auroraVeilTurns = duration;
        events.add(SimulationEvent(
          id: _uuid.v4(),
          message:
              'Aurora Veil protects ${pokemonIsTeam1 ? 'Team 1' : 'Team 2'}!',
          type: SimulationEventType.summary,
        ));
      }
    }
  }

  /// Remove screens when barrier-breaking moves are used
  void _removeScreens(
    BattlePokemon attacker,
    Move move,
    List<BattlePokemon> currentFieldTeam2,
    List<SimulationEvent> events,
  ) {
    // Check if move breaks barriers (Brick Break, Psychic Fangs, etc.)
    if (move.structuredEffects == null || move.structuredEffects!.isEmpty) {
      return;
    }

    for (final effect in move.structuredEffects!) {
      final effectType = effect['type'] as String?;
      if (effectType != 'BarrierBreakerEffect') {
        continue;
      }

      // Determine which team's screens to break
      final pokemonIsTeam1 = currentFieldTeam2
          .every((p) => p.originalName != attacker.originalName);
      final targetTeamKey = pokemonIsTeam1 ? 'team2' : 'team1';
      final targetScreenState = _screenStates[targetTeamKey]!;

      // Check what barriers this move breaks
      final breaksBarriers = effect['breaksBarriers'] as List?;
      if (breaksBarriers?.contains('Light Screen') ?? false) {
        if (targetScreenState.lightScreenTurns > 0) {
          targetScreenState.lightScreenTurns = 0;
          events.add(SimulationEvent(
            id: _uuid.v4(),
            message: 'Light Screen was broken!',
            type: SimulationEventType.summary,
          ));
        }
      }
      if (breaksBarriers?.contains('Reflect') ?? false) {
        if (targetScreenState.reflectTurns > 0) {
          targetScreenState.reflectTurns = 0;
          events.add(SimulationEvent(
            id: _uuid.v4(),
            message: 'Reflect was broken!',
            type: SimulationEventType.summary,
          ));
        }
      }
      if (breaksBarriers?.contains('Aurora Veil') ?? false) {
        if (targetScreenState.auroraVeilTurns > 0) {
          targetScreenState.auroraVeilTurns = 0;
          events.add(SimulationEvent(
            id: _uuid.v4(),
            message: 'Aurora Veil was broken!',
            type: SimulationEventType.summary,
          ));
        }
      }
    }
  }

  /// Build FieldState for damage calculator with current screen status
  FieldState _buildFieldState(List<BattlePokemon> currentFieldTeam1) {
    // Determine which team to check for screens (usually the defending team)
    // For now, return generic field state - this will be improved with proper team context
    return FieldState(
      lightScreenActive: _screenStates['team2']!.hasLightScreen,
      reflectActive: _screenStates['team2']!.hasReflect,
      auroraVeilActive: _screenStates['team2']!.hasAuroraVeil,
      lightScreenTurnsRemaining: _screenStates['team2']!.lightScreenTurns,
      reflectTurnsRemaining: _screenStates['team2']!.reflectTurns,
      auroraVeilTurnsRemaining: _screenStates['team2']!.auroraVeilTurns,
    );
  }

  /// Process status condition effects at end of turn (residual damage, etc.)
  List<SimulationEvent> _processStatusConditionEffects(BattlePokemon pokemon) {
    final events = <SimulationEvent>[];

    if (pokemon.status == null || pokemon.currentHp <= 0) {
      return events;
    }

    final status = pokemon.status!.toLowerCase();

    switch (status) {
      case 'burn':
        // Burn: 1/16 max HP damage per turn (1/32 with Heatproof ability)
        final damageRatio =
            pokemon.ability.toLowerCase() == 'heatproof' ? 32.0 : 16.0;
        final damage =
            (pokemon.maxHp / damageRatio).floor().clamp(1, pokemon.currentHp);
        final hpBefore = pokemon.currentHp;
        pokemon.currentHp -= damage;

        events.add(SimulationEvent(
          id: _uuid.v4(),
          message: '${pokemon.pokemonName} is hurt by its burn! (-$damage HP)',
          type: SimulationEventType.damageDealt,
          affectedPokemonName: pokemon.pokemonName,
          damageAmount: damage,
          hpBefore: hpBefore,
          hpAfter: pokemon.currentHp,
          maxHp: pokemon.maxHp,
        ));
        break;

      case 'poison':
        // Poison: 1/8 max HP damage per turn
        final damage = (pokemon.maxHp / 8).floor().clamp(1, pokemon.currentHp);
        final hpBefore = pokemon.currentHp;
        pokemon.currentHp -= damage;

        events.add(SimulationEvent(
          id: _uuid.v4(),
          message: '${pokemon.pokemonName} is hurt by poison! (-$damage HP)',
          type: SimulationEventType.damageDealt,
          affectedPokemonName: pokemon.pokemonName,
          damageAmount: damage,
          hpBefore: hpBefore,
          hpAfter: pokemon.currentHp,
          maxHp: pokemon.maxHp,
        ));
        break;

      case 'badpoison':
      case 'toxic':
        // Toxic: Increasing damage (1/16, 2/16, 3/16, etc.)
        final toxicCounter =
            (pokemon.volatileStatus['toxic_counter'] as int?) ?? 1;
        final damage = ((pokemon.maxHp * toxicCounter) / 16)
            .floor()
            .clamp(1, pokemon.currentHp);
        final hpBefore = pokemon.currentHp;
        pokemon.currentHp -= damage;
        pokemon.volatileStatus['toxic_counter'] = toxicCounter + 1;

        events.add(SimulationEvent(
          id: _uuid.v4(),
          message:
              '${pokemon.pokemonName} is hurt by toxic poison! (-$damage HP)',
          type: SimulationEventType.damageDealt,
          affectedPokemonName: pokemon.pokemonName,
          damageAmount: damage,
          hpBefore: hpBefore,
          hpAfter: pokemon.currentHp,
          maxHp: pokemon.maxHp,
        ));
        break;

      case 'sleep':
        // Sleep: Check if Pokemon wakes up (handled during move execution)
        // No residual damage for sleep
        break;

      case 'freeze':
        // Freeze: Check if Pokemon thaws (handled during move execution)
        // No residual damage for freeze
        break;

      case 'paralysis':
        // Paralysis: No residual damage (speed reduction handled in damage calculation)
        break;
    }

    // Check for fainting
    if (pokemon.currentHp <= 0) {
      pokemon.currentHp = 0;
      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${pokemon.pokemonName} fainted!',
        type: SimulationEventType.fainted,
        affectedPokemonName: pokemon.pokemonName,
      ));
    }

    return events;
  }

  /// Calculate confusion self-damage: 40 BP typeless physical attack
  /// Uses the pokemon's Attack and Defense stats but no type effectiveness
  int _calculateConfusionDamage(BattlePokemon pokemon) {
    // Base damage calculation: ((2 * Level / 5 + 2) * Power * Atk / Def) / 50 + 2
    // For confusion: Level = pokemon level, Power = 40, Atk = pokemon's Attack, Def = pokemon's Defense

    final level = 50; // Assume level 50 for now (TODO: get actual level)
    const power = 40;
    final attack = (pokemon.stats as dynamic).attack as int;
    final defense = (pokemon.stats as dynamic).defense as int;

    // Base damage
    final baseDamage =
        ((2 * level / 5 + 2) * power * attack / defense / 50 + 2).floor();

    // Add random factor (85-100% of base damage)
    final randomFactor = 85 + (DateTime.now().millisecond % 16); // 85-100
    final finalDamage = (baseDamage * randomFactor / 100).floor();

    return finalDamage.clamp(
        1, pokemon.currentHp); // Minimum 1 damage, max current HP
  }

  /// Decrement confusion turns and clear confusion if expired
  void _decrementConfusionTurns(
      BattlePokemon pokemon, List<SimulationEvent> events) {
    final turnsRemaining =
        pokemon.volatileStatus['confusion_turns_remaining'] as int?;

    if (turnsRemaining == null) {
      // No turn tracking, just remove confusion
      pokemon.volatileStatus.remove('confused');
      pokemon.volatileStatus.remove('confusion_turns_remaining');
      return;
    }

    final newTurns = turnsRemaining - 1;

    if (newTurns <= 0) {
      // Confusion expired
      pokemon.volatileStatus.remove('confused');
      pokemon.volatileStatus.remove('confusion_turns_remaining');

      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${pokemon.pokemonName} snapped out of confusion!',
        type: SimulationEventType.summary,
        affectedPokemonName: pokemon.originalName,
      ));
    } else {
      // Update remaining turns
      pokemon.volatileStatus['confusion_turns_remaining'] = newTurns;
    }
  }
}
