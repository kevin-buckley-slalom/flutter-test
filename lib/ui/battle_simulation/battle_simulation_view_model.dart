import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:championdex/data/models/team.dart';
import 'package:championdex/data/repositories/pokemon_repository.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/domain/battle/simulation_event.dart';
import 'package:championdex/domain/services/battle_simulation_engine.dart';
import 'package:championdex/domain/services/stat_calculator.dart';
import 'package:championdex/ui/pokemon_list/pokemon_list_view_model.dart';
import 'package:championdex/ui/teams_list/teams_list_view_model.dart';
import 'package:championdex/ui/moves_list/moves_list_view_model.dart';

class BattleSimulationNotifier extends Notifier<BattleUiState?> {
  @override
  BattleUiState? build() {
    return null;
  }

  /// Initializes the battle simulation with two teams and battle format
  Future<void> initializeBattle({
    required String team1Id,
    required String team2Id,
    required bool isSingles,
  }) async {
    try {
      final teamRepo = ref.read(teamRepositoryProvider);
      final pokemonRepo = ref.read(pokemonRepositoryProvider);

      // Initialize pokemon repository to load data
      await pokemonRepo.initialize();

      final team1 = await teamRepo.getById(team1Id);
      final team2 = await teamRepo.getById(team2Id);

      if (team1 == null || team2 == null) return;

      // Convert team members to battle pokemon
      final team1AllPokemon = await _buildBattleTeam(team1, pokemonRepo);
      final team2AllPokemon = await _buildBattleTeam(team2, pokemonRepo);

      // Get pokemon for battlefield based on battle format
      final battleSlots = isSingles ? 1 : 2;
      final team1FieldPokemon = <BattlePokemon?>[];
      final team2FieldPokemon = <BattlePokemon?>[];

      for (int i = 0; i < battleSlots; i++) {
        if (i < team1AllPokemon.length && team1AllPokemon[i] != null) {
          team1FieldPokemon.add(team1AllPokemon[i]);
        } else {
          team1FieldPokemon.add(null);
        }

        if (i < team2AllPokemon.length && team2AllPokemon[i] != null) {
          team2FieldPokemon.add(team2AllPokemon[i]);
        } else {
          team2FieldPokemon.add(null);
        }
      }

      // Initialize field conditions
      final fieldConditions = {
        'terrain': null,
        'weather': null,
        'rooms': [],
        'singleSideEffects': {
          'team1': [],
          'team2': [],
        },
        'otherEffects': [],
      };

      // Create initial state
      state = BattleUiState(
        team1Id: team1Id,
        team1Name: team1.name,
        team2Id: team2Id,
        team2Name: team2.name,
        isSinglesBattle: isSingles,
        team1Pokemon: team1FieldPokemon,
        team2Pokemon: team2FieldPokemon,
        team1Bench: team1AllPokemon
            .where((p) => p != null)
            .cast<BattlePokemon>()
            .toList(),
        team2Bench: team2AllPokemon
            .where((p) => p != null)
            .cast<BattlePokemon>()
            .toList(),
        fieldConditions: fieldConditions,
        simulationLog: [],
        isSimulationRunning: false,
        allActionsSet: false,
      );
    } catch (e) {
      print('Error initializing battle: $e');
    }
  }

  /// Converts a team into a list of BattlePokemon
  Future<List<BattlePokemon?>> _buildBattleTeam(
    Team team,
    PokemonRepository pokemonRepo,
  ) async {
    final battleTeam = <BattlePokemon?>[];

    for (final member in team.members) {
      if (member == null) {
        battleTeam.add(null);
        continue;
      }

      try {
        final pokemon = pokemonRepo.byName(member.pokemonName);
        if (pokemon == null) {
          battleTeam.add(null);
          continue;
        }

        // Calculate actual max HP using formula: floor(((2 * Base + IV + floor(EV/4)) * Level) / 100) + Level + 10
        final maxHp =
            ((2 * pokemon.stats.hp + member.ivHp + (member.evHp ~/ 4)) *
                        member.level) ~/
                    100 +
                member.level +
                10;

        // Calculate actual battle stats (not base stats)
        final calculatedStats = await StatCalculator.calculateBattleStats(
          baseStats: pokemon.stats,
          member: member,
        );

        final battlePokemon = BattlePokemon(
          pokemonName: member.pokemonName,
          originalName: member.pokemonName,
          maxHp: maxHp,
          currentHp: maxHp,
          level: member.level,
          ability: member.ability,
          item: member.item,
          isShiny: member.isShiny,
          teraType: member.teraType,
          moves: member.moves,
          statStages: {
            'hp': 0,
            'atk': 0,
            'def': 0,
            'spa': 0,
            'spd': 0,
            'spe': 0,
            'acc': 0,
            'eva': 0,
          },
          queuedAction: null,
          imagePath:
              member.isShiny ? pokemon.imageShinyPath : pokemon.imagePath,
          imagePathLarge: member.isShiny
              ? pokemon.imageShinyPathLarge
              : pokemon.imagePathLarge,
          stats: calculatedStats,
          types: pokemon.types,
          status: null,
        );

        battleTeam.add(battlePokemon);
      } catch (e) {
        print('Error building battle pokemon ${member.pokemonName}: $e');
        battleTeam.add(null);
      }
    }

    return battleTeam;
  }

  /// Updates a battlefield pokemon's queued action
  void setQueuedAction(bool isTeam1, int slotIndex, BattleAction? action) {
    if (state == null) return;

    final updatedTeam1 = state!.team1Pokemon.toList();
    final updatedTeam2 = state!.team2Pokemon.toList();

    if (isTeam1) {
      if (slotIndex < updatedTeam1.length && updatedTeam1[slotIndex] != null) {
        updatedTeam1[slotIndex] = updatedTeam1[slotIndex]!.copyWith(
          queuedAction: action,
          clearQueuedAction: action == null,
        );
      }
    } else {
      if (slotIndex < updatedTeam2.length && updatedTeam2[slotIndex] != null) {
        updatedTeam2[slotIndex] = updatedTeam2[slotIndex]!.copyWith(
          queuedAction: action,
          clearQueuedAction: action == null,
        );
      }
    }

    _updateActionStatus(updatedTeam1, updatedTeam2);

    state = state!.copyWith(
      team1Pokemon: updatedTeam1,
      team2Pokemon: updatedTeam2,
    );
  }

  /// Updates a battlefield pokemon's current HP
  void setCurrentHp(bool isTeam1, int slotIndex, int newHp) {
    if (state == null) return;

    final updatedTeam1 = state!.team1Pokemon.toList();
    final updatedTeam2 = state!.team2Pokemon.toList();

    if (isTeam1) {
      if (slotIndex < updatedTeam1.length && updatedTeam1[slotIndex] != null) {
        final pokemon = updatedTeam1[slotIndex]!;
        updatedTeam1[slotIndex] = pokemon.copyWith(
          currentHp: newHp.clamp(0, pokemon.maxHp),
        );
      }
    } else {
      if (slotIndex < updatedTeam2.length && updatedTeam2[slotIndex] != null) {
        final pokemon = updatedTeam2[slotIndex]!;
        updatedTeam2[slotIndex] = pokemon.copyWith(
          currentHp: newHp.clamp(0, pokemon.maxHp),
        );
      }
    }

    state = state!.copyWith(
      team1Pokemon: updatedTeam1,
      team2Pokemon: updatedTeam2,
    );
  }

  /// Updates a stat stage modifier for a battlefield pokemon
  void setStatStage(bool isTeam1, int slotIndex, String stat, int stage) {
    if (state == null) return;

    final updatedTeam1 = state!.team1Pokemon.toList();
    final updatedTeam2 = state!.team2Pokemon.toList();

    if (isTeam1) {
      if (slotIndex < updatedTeam1.length && updatedTeam1[slotIndex] != null) {
        final pokemon = updatedTeam1[slotIndex]!;
        final newStages = Map<String, int>.from(pokemon.statStages);
        newStages[stat] = stage.clamp(-6, 6);
        updatedTeam1[slotIndex] = pokemon.copyWith(statStages: newStages);
      }
    } else {
      if (slotIndex < updatedTeam2.length && updatedTeam2[slotIndex] != null) {
        final pokemon = updatedTeam2[slotIndex]!;
        final newStages = Map<String, int>.from(pokemon.statStages);
        newStages[stat] = stage.clamp(-6, 6);
        updatedTeam2[slotIndex] = pokemon.copyWith(statStages: newStages);
      }
    }

    state = state!.copyWith(
      team1Pokemon: updatedTeam1,
      team2Pokemon: updatedTeam2,
    );
  }

  /// Switches a pokemon in the battle (swaps field pokemon with reserve)
  void switchPokemon(
      bool isTeam1, int slotIndex, BattlePokemon reservePokemon) {
    if (state == null) return;

    final updatedTeam1 = state!.team1Pokemon.toList();
    final updatedTeam2 = state!.team2Pokemon.toList();
    final updatedTeam1Bench = state!.team1Bench.toList();
    final updatedTeam2Bench = state!.team2Bench.toList();

    if (isTeam1) {
      if (slotIndex < updatedTeam1.length && updatedTeam1[slotIndex] != null) {
        final currentPokemon = updatedTeam1[slotIndex]!;

        // Swap: put reserve pokemon in field slot
        updatedTeam1[slotIndex] = reservePokemon;

        // Ensure bench doesn't contain either before adding current
        updatedTeam1Bench.removeWhere((p) =>
            p.pokemonName == reservePokemon.pokemonName ||
            p.pokemonName == currentPokemon.pokemonName);

        // Add current pokemon to bench
        updatedTeam1Bench.add(currentPokemon);
      }
    } else {
      if (slotIndex < updatedTeam2.length && updatedTeam2[slotIndex] != null) {
        final currentPokemon = updatedTeam2[slotIndex]!;

        // Swap: put reserve pokemon in field slot
        updatedTeam2[slotIndex] = reservePokemon;

        // Ensure bench doesn't contain either before adding current
        updatedTeam2Bench.removeWhere((p) =>
            p.pokemonName == reservePokemon.pokemonName ||
            p.pokemonName == currentPokemon.pokemonName);

        // Add current pokemon to bench
        updatedTeam2Bench.add(currentPokemon);
      }
    }

    state = state!.copyWith(
      team1Pokemon: updatedTeam1,
      team2Pokemon: updatedTeam2,
      team1Bench: updatedTeam1Bench,
      team2Bench: updatedTeam2Bench,
    );
  }

  /// Updates field conditions
  void setFieldCondition(String category, dynamic value) {
    if (state == null) return;

    final updatedConditions = Map<String, dynamic>.from(state!.fieldConditions);
    updatedConditions[category] = value;

    state = state!.copyWith(fieldConditions: updatedConditions);
  }

  /// Adds a log message to the simulation log
  void addSimulationLogEntry(SimulationEvent event) {
    if (state == null) return;

    final updatedLog = state!.simulationLog.toList();
    updatedLog.add(event);

    state = state!.copyWith(simulationLog: updatedLog);
  }

  /// Clears the simulation log
  void clearSimulationLog() {
    if (state == null) return;

    state = state!.copyWith(simulationLog: []);
  }

  /// Modifies an event outcome and marks downstream events as stale
  void modifyEventOutcome(int eventIndex, EventModification modification) {
    if (state == null || eventIndex >= state!.simulationLog.length) return;

    final updatedLog = state!.simulationLog.toList();
    final event = updatedLog[eventIndex];

    // Update the event with the modification
    updatedLog[eventIndex] = event.copyWith(
      modification: modification,
      isModified: true,
    );

    // Mark all downstream events as needing recalculation
    for (int i = eventIndex + 1; i < updatedLog.length; i++) {
      updatedLog[i] = updatedLog[i].copyWith(needsRecalculation: true);
    }

    state = state!.copyWith(simulationLog: updatedLog);
  }

  /// Reruns simulation from a specific event index
  Future<void> rerunFromEvent(int eventIndex) async {
    if (state == null || eventIndex >= state!.simulationLog.length) return;

    final event = state!.simulationLog[eventIndex];
    final snapshot = event.stateSnapshot;

    if (snapshot == null) {
      print('Cannot rerun: no state snapshot available');
      return;
    }

    try {
      state = state!.copyWith(isSimulationRunning: true);

      // Restore state from snapshot
      final restoredTeam1 =
          snapshot.team1Field.map((p) => p as BattlePokemon?).toList();
      final restoredTeam2 =
          snapshot.team2Field.map((p) => p as BattlePokemon?).toList();

      // Apply the modification to the restored state
      final modifiedEvent = state!.simulationLog[eventIndex];
      BattlePokemon? modifiedDefender;
      bool isForcedMiss = false;

      if (modifiedEvent.modification != null &&
          modifiedEvent.type == SimulationEventType.damageDealt) {
        // Check if this is a forced miss
        if (modifiedEvent.modification!.forceMiss == true) {
          isForcedMiss = true;
          // Don't apply damage - the move missed
        } else {
          // Apply modified damage
          final defenderName = modifiedEvent.affectedPokemonName;
          if (defenderName != null) {
            final defender = [...restoredTeam1, ...restoredTeam2]
                .whereType<BattlePokemon>()
                .firstWhere((p) => p.originalName == defenderName);

            final selectedDamage =
                modifiedEvent.modification!.selectedDamageRoll ??
                    modifiedEvent.damageAmount!;
            defender.currentHp = (modifiedEvent.hpBefore! - selectedDamage)
                .clamp(0, defender.maxHp);
            modifiedDefender = defender;
          }
        }
      }

      // Keep events up to and including the modified event,
      // PLUS any subsequent events from the same move (like Volt Switch's switch)
      int lastEventIndex = eventIndex;
      final moveName = modifiedEvent.moveName;
      final sourcePokemon = modifiedEvent.sourcePokemonName;

      // If forced miss, we want to replace damage event with miss event
      // So we need to exclude events after the damage (no switches, no KOs)
      if (isForcedMiss) {
        // Only keep events up to (but not including) the damage event
        lastEventIndex = eventIndex - 1;
      } else {
        // Look ahead for events from the same move
        // Keep all events until we hit the next moveUsed event
        for (int i = eventIndex + 1; i < state!.simulationLog.length; i++) {
          final nextEvent = state!.simulationLog[i];
          // Stop at the next moveUsed event (start of different move)
          if (nextEvent.type == SimulationEventType.moveUsed) {
            break;
          }
          // Keep all non-moveUsed events (switched, fainted, etc. from same move)
          lastEventIndex = i;
        }
      }

      final keptEvents = state!.simulationLog
          .sublist(0, lastEventIndex + 1)
          .map((e) => e.copyWith(
                needsRecalculation: false,
              ))
          .toList();

      // If forced miss, replace the damage event with a miss event
      if (isForcedMiss) {
        final missEvent = SimulationEvent(
          id: modifiedEvent.id, // Keep same ID
          type: SimulationEventType.missed,
          message: '${modifiedEvent.sourcePokemonName}\'s attack missed!',
          sourcePokemonName: modifiedEvent.sourcePokemonName,
          affectedPokemonName: modifiedEvent.affectedPokemonName,
          moveName: modifiedEvent.moveName,
          isModified: true,
          isEditable: true, // Keep editable so user can undo
          variations:
              modifiedEvent.variations, // Preserve damage rolls and variations
          modification:
              modifiedEvent.modification, // Preserve modification state
          stateSnapshot:
              modifiedEvent.stateSnapshot, // Preserve state for replay
          damageAmount: modifiedEvent.damageAmount, // Preserve original damage
          hpBefore: modifiedEvent.hpBefore,
          hpAfter: modifiedEvent.hpAfter,
          maxHp: modifiedEvent.maxHp,
        );
        keptEvents.add(missEvent);
      }

      // Update the modified event's message to reflect the new damage value (if not a miss)
      if (!isForcedMiss &&
          modifiedEvent.modification != null &&
          modifiedEvent.type == SimulationEventType.damageDealt) {
        final selectedDamage = modifiedEvent.modification!.selectedDamageRoll ??
            modifiedEvent.damageAmount!;
        final affectedPokemon = modifiedEvent.affectedPokemonName;
        final damageRange = modifiedEvent.variations?.damageRolls;

        if (affectedPokemon != null && damageRange != null) {
          final minDamage = damageRange.reduce((a, b) => a < b ? a : b);
          final maxDamage = damageRange.reduce((a, b) => a > b ? a : b);

          // Find and update the modified event in keptEvents
          for (int i = 0; i < keptEvents.length; i++) {
            if (keptEvents[i].id == modifiedEvent.id) {
              keptEvents[i] = keptEvents[i].copyWith(
                message:
                    '$affectedPokemon took $selectedDamage damage! (range: $minDamage-$maxDamage)',
                damageAmount: selectedDamage,
              );
              break;
            }
          }
        }
      }

      // Check if modified damage caused a KO that wasn't in original events
      if (modifiedDefender != null && modifiedDefender.currentHp == 0) {
        // Check if there's already a fainted event for this pokemon in kept events
        final alreadyHasFaintedEvent = keptEvents.any((e) =>
            e.type == SimulationEventType.fainted &&
            e.affectedPokemonName == modifiedDefender?.originalName);

        if (!alreadyHasFaintedEvent) {
          // Insert knockout event immediately after the damage event
          // This ensures abilities/effects trigger before switches
          final koEvent = SimulationEvent(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: SimulationEventType.fainted,
            message: '${modifiedDefender.pokemonName} fainted!',
            affectedPokemonName: modifiedDefender.originalName,
          );
          keptEvents.insert(eventIndex + 1, koEvent);
        }
      }

      // Apply any switches from kept events to the restored state
      // This ensures remaining moves target the correct pokemon
      for (final event in keptEvents) {
        if (event.type == SimulationEventType.summary &&
            event.message.contains('switched out!')) {
          // Find the next "Go!" event to identify the switched-in pokemon
          final switchedOutIndex = keptEvents.indexOf(event);
          if (switchedOutIndex >= 0 &&
              switchedOutIndex + 1 < keptEvents.length) {
            final nextEvent = keptEvents[switchedOutIndex + 1];
            if (nextEvent.message.startsWith('Go!') &&
                nextEvent.affectedPokemonName != null) {
              final switchedInName = nextEvent.affectedPokemonName!;

              // Extract the switched-out pokemon name from the message
              final switchedOutName = event.message.split(' switched out!')[0];

              // Find which team and slot
              for (int i = 0; i < restoredTeam1.length; i++) {
                if (restoredTeam1[i]?.pokemonName == switchedOutName) {
                  // Find the switch-in pokemon from bench
                  final switchInPokemon = snapshot.team1Bench
                      .firstWhere((p) => p.originalName == switchedInName);
                  restoredTeam1[i] = switchInPokemon;
                  break;
                }
              }

              for (int i = 0; i < restoredTeam2.length; i++) {
                if (restoredTeam2[i]?.pokemonName == switchedOutName) {
                  // Find the switch-in pokemon from bench
                  final switchInPokemon = snapshot.team2Bench
                      .firstWhere((p) => p.originalName == switchedInName);
                  restoredTeam2[i] = switchInPokemon;
                  break;
                }
              }
            }
          }
        }
      }

      // Figure out which pokemon have already moved by looking at kept events
      final alreadyMoved = <String>{};
      for (final e in keptEvents) {
        if (e.type == SimulationEventType.moveUsed &&
            e.sourcePokemonName != null) {
          alreadyMoved.add(e.sourcePokemonName!);
        }
      }

      print('Already moved: $alreadyMoved');

      // Debug: Check all pokemon in restored state
      final allPokemon = [...state!.team1Pokemon, ...state!.team2Pokemon];
      print(
          'Total pokemon in restored state: ${allPokemon.where((p) => p != null).length}');
      for (final pokemon in allPokemon) {
        if (pokemon != null) {
          print(
              '  Pokemon: ${pokemon.originalName}, queuedAction: ${pokemon.queuedAction}');
        }
      }

      // Re-run the turn with the modified state, but only with actions that haven't been executed yet
      final moveRepo = ref.read(moveRepositoryProvider);
      final movesList = await moveRepo.getAllMoves();
      final moveDatabase = <String, dynamic>{};
      for (final move in movesList) {
        moveDatabase[move.name] = move;
      }

      // Create actions map excluding pokemon that have already moved
      // Use the original actions map from simulation start
      final remainingActionsMap = <String, BattleAction>{};
      for (final entry in state!.originalActionsMap.entries) {
        final pokemonName = entry.key;
        final action = entry.value;

        // Only include if this pokemon hasn't moved yet
        if (!alreadyMoved.contains(pokemonName)) {
          remainingActionsMap[pokemonName] = action;
          print('Adding remaining action for: $pokemonName - $action');
        } else {
          print('Skipping $pokemonName - already moved');
        }
      }

      print('Remaining actions map size: ${remainingActionsMap.length}');

      // Create engine and process remaining actions
      final engine = BattleSimulationEngine(
        moveDatabase: moveDatabase,
      );

      await engine.initialize();

      // Process turn from modified state with only remaining actions
      final outcome = engine.processTurn(
        team1Active: restoredTeam1.whereType<BattlePokemon>().toList(),
        team2Active: restoredTeam2.whereType<BattlePokemon>().toList(),
        team1Bench: snapshot.team1Bench,
        team2Bench: snapshot.team2Bench,
        actionsMap: remainingActionsMap,
        fieldConditions: state!.fieldConditions,
      );

      print('Outcome events count: ${outcome.events.length}');
      for (final e in outcome.events) {
        print('  - ${e.type}: ${e.message}');
      }

      // Combine kept events with new events from rerun
      final updatedLog = [...keptEvents, ...outcome.events];

      print(
          'Final log size: ${updatedLog.length} (kept: ${keptEvents.length}, new: ${outcome.events.length})');

      // Update pokemon states from outcome
      final updatedTeam1 = <BattlePokemon?>[];
      for (final pokemon in outcome.team1FinalField) {
        if (pokemon != null &&
            outcome.finalStates.containsKey(pokemon.originalName)) {
          updatedTeam1.add(outcome.finalStates[pokemon.originalName]);
        } else {
          updatedTeam1.add(pokemon);
        }
      }

      final updatedTeam2 = <BattlePokemon?>[];
      for (final pokemon in outcome.team2FinalField) {
        if (pokemon != null &&
            outcome.finalStates.containsKey(pokemon.originalName)) {
          updatedTeam2.add(outcome.finalStates[pokemon.originalName]);
        } else {
          updatedTeam2.add(pokemon);
        }
      }

      final updatedTeam1Bench = <BattlePokemon>[];
      for (final pokemon in outcome.team1FinalBench) {
        if (outcome.finalStates.containsKey(pokemon.originalName)) {
          updatedTeam1Bench.add(outcome.finalStates[pokemon.originalName]!);
        } else {
          updatedTeam1Bench.add(pokemon);
        }
      }

      final updatedTeam2Bench = <BattlePokemon>[];
      for (final pokemon in outcome.team2FinalBench) {
        if (outcome.finalStates.containsKey(pokemon.originalName)) {
          updatedTeam2Bench.add(outcome.finalStates[pokemon.originalName]!);
        } else {
          updatedTeam2Bench.add(pokemon);
        }
      }

      state = state!.copyWith(
        team1Pokemon: updatedTeam1,
        team2Pokemon: updatedTeam2,
        team1Bench: updatedTeam1Bench,
        team2Bench: updatedTeam2Bench,
        simulationLog: updatedLog,
        isSimulationRunning: false,
      );
    } catch (e) {
      print('Error rerunning simulation: $e');
      state = state!.copyWith(isSimulationRunning: false);
    }
  }

  /// Checks if all battlefield pokemon have actions set, updates allActionsSet
  void _updateActionStatus(
    List<BattlePokemon?> team1Pokemon,
    List<BattlePokemon?> team2Pokemon,
  ) {
    bool allSet = true;

    for (final pokemon in team1Pokemon) {
      if (pokemon != null && pokemon.queuedAction == null) {
        allSet = false;
        break;
      }
    }

    if (allSet) {
      for (final pokemon in team2Pokemon) {
        if (pokemon != null && pokemon.queuedAction == null) {
          allSet = false;
          break;
        }
      }
    }

    if (state != null) {
      state = state!.copyWith(allActionsSet: allSet);
    }
  }

  /// Starts the simulation and processes a turn of battle
  Future<void> startSimulation() async {
    if (state == null || !state!.allActionsSet) return;

    try {
      // Get move database and convert to map
      final moveRepo = ref.read(moveRepositoryProvider);
      final movesList = await moveRepo.getAllMoves();
      final moveDatabase = <String, dynamic>{};
      for (final move in movesList) {
        moveDatabase[move.name] = move;
      }

      // Create action map from queued actions
      final actionsMap = <String, BattleAction>{};
      for (final pokemon in state!.team1Pokemon) {
        if (pokemon != null && pokemon.queuedAction != null) {
          actionsMap[pokemon.originalName] = pokemon.queuedAction!;
        }
      }
      for (final pokemon in state!.team2Pokemon) {
        if (pokemon != null && pokemon.queuedAction != null) {
          actionsMap[pokemon.originalName] = pokemon.queuedAction!;
        }
      }

      state = state!.copyWith(
        isSimulationRunning: true,
        simulationLog: [],
        originalActionsMap: actionsMap, // Store for replay
      );

      // Create engine and process turn
      final engine = BattleSimulationEngine(
        moveDatabase: moveDatabase,
      );

      // Initialize the engine (loads type chart)
      await engine.initialize();

      // Get active pokemon
      final team1Active =
          state!.team1Pokemon.whereType<BattlePokemon>().toList();
      final team2Active =
          state!.team2Pokemon.whereType<BattlePokemon>().toList();

      final team1ActiveNames = team1Active.map((p) => p.originalName).toSet();
      final team2ActiveNames = team2Active.map((p) => p.originalName).toSet();

      final team1Bench = state!.team1Bench
          .where((p) => !team1ActiveNames.contains(p.originalName))
          .toList();
      final team2Bench = state!.team2Bench
          .where((p) => !team2ActiveNames.contains(p.originalName))
          .toList();

      final outcome = engine.processTurn(
        team1Active: team1Active,
        team2Active: team2Active,
        team1Bench: team1Bench,
        team2Bench: team2Bench,
        actionsMap: actionsMap,
        fieldConditions: state!.fieldConditions,
      );

      // Update state with rich simulation events
      final updatedLog = <SimulationEvent>[...outcome.events];

      // Update pokemon states from outcome using the final field composition
      // The engine returns which pokemon ended up on the field after switches
      final updatedTeam1 = <BattlePokemon?>[];
      for (final pokemon in outcome.team1FinalField) {
        if (pokemon != null &&
            outcome.finalStates.containsKey(pokemon.originalName)) {
          updatedTeam1.add(outcome.finalStates[pokemon.originalName]);
        } else {
          updatedTeam1.add(pokemon);
        }
      }

      final updatedTeam2 = <BattlePokemon?>[];
      for (final pokemon in outcome.team2FinalField) {
        if (pokemon != null &&
            outcome.finalStates.containsKey(pokemon.originalName)) {
          updatedTeam2.add(outcome.finalStates[pokemon.originalName]);
        } else {
          updatedTeam2.add(pokemon);
        }
      }

      final updatedTeam1Bench = <BattlePokemon>[];
      for (final pokemon in outcome.team1FinalBench) {
        final statePokemon = outcome.finalStates[pokemon.originalName];
        updatedTeam1Bench.add(statePokemon ?? pokemon);
      }

      final updatedTeam2Bench = <BattlePokemon>[];
      for (final pokemon in outcome.team2FinalBench) {
        final statePokemon = outcome.finalStates[pokemon.originalName];
        updatedTeam2Bench.add(statePokemon ?? pokemon);
      }

      final clearedTeam1 = updatedTeam1
          .map((p) => p?.copyWith(clearQueuedAction: true))
          .toList();
      final clearedTeam2 = updatedTeam2
          .map((p) => p?.copyWith(clearQueuedAction: true))
          .toList();
      final clearedTeam1Bench = updatedTeam1Bench
          .map((p) => p.copyWith(clearQueuedAction: true))
          .toList();
      final clearedTeam2Bench = updatedTeam2Bench
          .map((p) => p.copyWith(clearQueuedAction: true))
          .toList();

      state = state!.copyWith(
        team1Pokemon: clearedTeam1,
        team2Pokemon: clearedTeam2,
        team1Bench: clearedTeam1Bench,
        team2Bench: clearedTeam2Bench,
        simulationLog: updatedLog,
        isSimulationRunning: false,
        allActionsSet: false,
      );
    } catch (e) {
      print('Error running simulation: $e');
      state = state!.copyWith(
        isSimulationRunning: false,
      );
    }
  }

  /// Stops the simulation
  void stopSimulation() {
    if (state == null) return;

    state = state!.copyWith(isSimulationRunning: false);
  }
}

final battleSimulationViewModelProvider =
    NotifierProvider<BattleSimulationNotifier, BattleUiState?>(() {
  return BattleSimulationNotifier();
});
