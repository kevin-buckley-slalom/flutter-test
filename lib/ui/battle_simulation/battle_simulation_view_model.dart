import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:championdex/data/models/team.dart';
import 'package:championdex/data/repositories/pokemon_repository.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
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
  void addSimulationLogEntry(String message) {
    if (state == null) return;

    final updatedLog = state!.simulationLog.toList();
    updatedLog.add(message);

    state = state!.copyWith(simulationLog: updatedLog);
  }

  /// Clears the simulation log
  void clearSimulationLog() {
    if (state == null) return;

    state = state!.copyWith(simulationLog: []);
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
      state = state!.copyWith(
        isSimulationRunning: true,
        simulationLog: ['Battle started!'],
      );

      // Get move database and convert to map
      final moveRepo = ref.read(moveRepositoryProvider);
      final movesList = await moveRepo.getAllMoves();
      final moveDatabase = <String, dynamic>{};
      for (final move in movesList) {
        moveDatabase[move.name] = move;
      }

      // Get pokemon types (simplified - load from pokemon repo)
      final pokemonRepo = ref.read(pokemonRepositoryProvider);
      final pokemonTypesMap = <String, List<String>>{};

      // Build pokemon types map from active pokemon
      for (final pokemon in state!.team1Pokemon) {
        if (pokemon != null) {
          final fullPokemon = pokemonRepo.byName(pokemon.pokemonName);
          if (fullPokemon != null) {
            pokemonTypesMap[pokemon.pokemonName] = fullPokemon.types;
          }
        }
      }

      for (final pokemon in state!.team2Pokemon) {
        if (pokemon != null) {
          final fullPokemon = pokemonRepo.byName(pokemon.pokemonName);
          if (fullPokemon != null) {
            pokemonTypesMap[pokemon.pokemonName] = fullPokemon.types;
          }
        }
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

      // Create engine and process turn
      final engine = BattleSimulationEngine(
        moveDatabase: moveDatabase,
        pokemonTypesMap: pokemonTypesMap,
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

      // Update state with simulation log and results
      final updatedLog = <String>[...state!.simulationLog];
      for (final event in outcome.events) {
        updatedLog.add(event.message);
      }

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

      // Add outcome summary
      updatedLog.add('---');
      updatedLog.add('Turn Summary:');
      for (final entry in outcome.probabilities.entries) {
        final formattedEntry = _formatSummaryEntry(entry.key, entry.value);
        if (formattedEntry != null) {
          updatedLog.add(formattedEntry);
        }
      }

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
      final updatedLog = <String>[...state!.simulationLog];
      updatedLog.add('Error: $e');
      state = state!.copyWith(
        simulationLog: updatedLog,
        isSimulationRunning: false,
      );
    }
  }

  /// Stops the simulation
  void stopSimulation() {
    if (state == null) return;

    state = state!.copyWith(isSimulationRunning: false);
  }

  /// Format a summary entry key-value pair into a readable string
  String? _formatSummaryEntry(String key, dynamic value) {
    // Handle knockouts
    if (key == 'knockoutsOccurred') {
      return 'Knockouts Occurred: $value';
    }

    // Handle HP percentages
    if (key.endsWith('_hp_percent')) {
      final pokemonName =
          key.replaceAll('_hp_percent', '').replaceAll('-', ' ');
      // Capitalize first letter of each word
      final formattedName = pokemonName.split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');

      if (value is num) {
        final percentage = value.toStringAsFixed(1);
        return '$formattedName HP Remaining: $percentage%';
      }
    }

    // For any other keys, convert snake_case to Title Case
    final formattedKey = key.split('_').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    return '$formattedKey: $value';
  }
}

final battleSimulationViewModelProvider =
    NotifierProvider<BattleSimulationNotifier, BattleUiState?>(() {
  return BattleSimulationNotifier();
});
