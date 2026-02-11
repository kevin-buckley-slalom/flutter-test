import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/data/models/move.dart';

/// Represents a single turn action with its executor and speed priority
class TurnAction {
  final BattlePokemon pokemon;
  final BattleAction action;
  final Move? move; // null if switch action
  final int executionOrder; // lower = goes first

  TurnAction({
    required this.pokemon,
    required this.action,
    required this.move,
    required this.executionOrder,
  });
}

/// Calculates action order based on speed stats, move priority, and field effects
class TurnOrderCalculator {
  /// Calculates the execution order for all active Pokémon in a turn
  ///
  /// Order is determined by:
  /// 1. Move priority (higher priority first)
  /// 2. Speed stat + modifiers (faster goes first for same priority)
  /// 3. Field effects like Trick Room (reverses speed order)
  static List<TurnAction> calculateTurnOrder({
    required List<BattlePokemon> allActivePokemon,
    required Map<String, BattleAction> actionsMap, // pokemonName -> action
    required Map<String, dynamic> moveDatabase, // move name -> Move
    required bool isTrickRoomActive,
    required bool isChildsPlayActive, // reverses order
  }) {
    final turnActions = <TurnAction>[];

    // Build turn actions with priority and speed data
    for (final pokemon in allActivePokemon) {
      final action = actionsMap[pokemon.originalName];
      if (action == null) continue;

      dynamic moveData;

      // Get move data if it's an attack action
      if (action is AttackAction) {
        final move = moveDatabase[action.moveName];
        moveData = move;
      }

      turnActions.add(TurnAction(
        pokemon: pokemon,
        action: action,
        move: moveData,
        executionOrder: 0, // will be set during sort
      ));
    }

    // Sort by priority (descending) then by speed (descending)
    turnActions.sort((a, b) {
      var priorityA = a.move?.priority ?? 0;
      var priorityB = b.move?.priority ?? 0;

      // Apply Prankster ability: +1 priority to status moves
      if (a.pokemon.ability.toLowerCase() == 'prankster' &&
          a.move != null &&
          a.move!.category.toLowerCase() == 'status') {
        priorityA += 1;
      }
      if (b.pokemon.ability.toLowerCase() == 'prankster' &&
          b.move != null &&
          b.move!.category.toLowerCase() == 'status') {
        priorityB += 1;
      }

      if (priorityA != priorityB) {
        return priorityB.compareTo(priorityA); // higher priority first
      }

      // For same priority, sort by speed
      final speedA = _calculateEffectiveSpeed(a.pokemon, isTrickRoomActive);
      final speedB = _calculateEffectiveSpeed(b.pokemon, isTrickRoomActive);

      if (isTrickRoomActive) {
        return speedA.compareTo(speedB); // slower first
      } else {
        return speedB.compareTo(speedA); // faster first
      }
    });

    // Update execution order indices
    for (var i = 0; i < turnActions.length; i++) {
      turnActions[i] = TurnAction(
        pokemon: turnActions[i].pokemon,
        action: turnActions[i].action,
        move: turnActions[i].move,
        executionOrder: i,
      );
    }

    return turnActions;
  }

  /// Calculate effective speed considering stat stages and field effects
  static int _calculateEffectiveSpeed(
    BattlePokemon pokemon,
    bool isTrickRoomActive,
  ) {
    final baseStat = pokemon.stats?.speed ?? 100;
    final speedStage = pokemon.statStages['spe'] ?? 0;

    // Apply stat stage multiplier
    double speedMultiplier = _getStatMultiplier(speedStage);
    int effectiveSpeed = (baseStat * speedMultiplier).toInt();

    // Apply paralysis speed reduction (halved, unless Quick Feet ability)
    if (pokemon.status?.toLowerCase() == 'paralysis') {
      if (pokemon.ability.toLowerCase() == 'quick feet') {
        // Quick Feet increases speed by 50% instead
        effectiveSpeed = (effectiveSpeed * 1.5).toInt();
      } else {
        // Paralysis halves speed
        effectiveSpeed = (effectiveSpeed * 0.5).toInt();
      }
    }

    // Trick Room effect: reverses speed order for that turn
    // (handled in sort logic, not here)

    return effectiveSpeed;
  }

  /// Get the stat multiplier for a given stat stage (-6 to +6)
  static double _getStatMultiplier(int stage) {
    if (stage >= 0) {
      return 1 + (stage * 0.5); // +1 stage = 1.5x, +2 = 2.0x, etc
    } else {
      return 1 / (1 + ((-stage) * 0.5)); // -1 stage = 0.67x, -2 = 0.5x, etc
    }
  }
}
