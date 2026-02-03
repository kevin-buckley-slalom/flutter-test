import 'package:championdex/domain/battle/battle_ui_state.dart';

/// Types of events that can occur during battle simulation
enum SimulationEventType {
  turnStart,
  moveUsed,
  damageDealt,
  statusApplied,
  statChanged,
  switched,
  fainted,
  missed,
  protected,
  effectivenessMessage,
  summary,
  abilityActivation,
  weatherChange,
  heal,
  itemActivation,
}

/// Represents possible variations for an event outcome
class EventVariations {
  /// All possible damage values (for damage events)
  final List<int>? damageRolls;

  /// Whether a critical hit could occur
  final bool canCrit;

  /// Hit chance (0.0 to 1.0)
  final double hitChance;

  /// Whether the move could miss
  final bool canMiss;

  /// Type effectiveness multiplier
  final double? effectiveness;

  /// Effectiveness description
  final String? effectivenessString;

  const EventVariations({
    this.damageRolls,
    this.canCrit = false,
    this.hitChance = 1.0,
    this.canMiss = false,
    this.effectiveness,
    this.effectivenessString,
  });

  EventVariations copyWith({
    List<int>? damageRolls,
    bool? canCrit,
    double? hitChance,
    bool? canMiss,
    double? effectiveness,
    String? effectivenessString,
  }) {
    return EventVariations(
      damageRolls: damageRolls ?? this.damageRolls,
      canCrit: canCrit ?? this.canCrit,
      hitChance: hitChance ?? this.hitChance,
      canMiss: canMiss ?? this.canMiss,
      effectiveness: effectiveness ?? this.effectiveness,
      effectivenessString: effectivenessString ?? this.effectivenessString,
    );
  }
}

/// User modifications to an event's outcome
class EventModification {
  /// Selected damage roll (if different from default)
  final int? selectedDamageRoll;

  /// Force critical hit
  final bool? forceCrit;

  /// Force miss
  final bool? forceMiss;

  const EventModification({
    this.selectedDamageRoll,
    this.forceCrit,
    this.forceMiss,
  });
}

/// A single event in the battle simulation
class SimulationEvent {
  /// Unique identifier for this event
  final String id;

  /// Type of event
  final SimulationEventType type;

  /// Display message
  final String message;

  /// Pokemon affected by this event
  final String? affectedPokemonName;

  /// Pokemon that caused this event (attacker)
  final String? sourcePokemonName;

  /// Move name (for move-related events)
  final String? moveName;

  /// Damage amount (for damage events)
  final int? damageAmount;

  /// HP before event
  final int? hpBefore;

  /// HP after event
  final int? hpAfter;

  /// Max HP of affected pokemon
  final int? maxHp;

  /// Possible variations for this event
  final EventVariations? variations;

  /// User modifications to this event
  final EventModification? modification;

  /// Whether this event can be edited
  final bool isEditable;

  /// Whether this event was modified by the user
  final bool isModified;

  /// Whether downstream events need recalculation
  final bool needsRecalculation;

  /// Complete battle state snapshot before this event
  final BattleStateSnapshot? stateSnapshot;

  const SimulationEvent({
    required this.id,
    required this.type,
    required this.message,
    this.affectedPokemonName,
    this.sourcePokemonName,
    this.moveName,
    this.damageAmount,
    this.hpBefore,
    this.hpAfter,
    this.maxHp,
    this.variations,
    this.modification,
    this.isEditable = false,
    this.isModified = false,
    this.needsRecalculation = false,
    this.stateSnapshot,
  });

  /// Calculate survival/knockout probability based on damage rolls
  KnockoutProbability? getKnockoutProbability() {
    if (variations?.damageRolls == null || hpBefore == null) return null;

    final rolls = variations!.damageRolls!;
    final currentHp = hpBefore!;

    int koCount = 0;
    int surviveCount = 0;

    for (final damage in rolls) {
      if (damage >= currentHp) {
        koCount++;
      } else {
        surviveCount++;
      }
    }

    final total = rolls.length;
    final koChance = koCount / total;
    final survivalChance = surviveCount / total;

    return KnockoutProbability(
      knockoutChance: koChance,
      survivalChance: survivalChance,
      willAlwaysKO: koCount == total,
      willAlwaysSurvive: surviveCount == total,
    );
  }

  SimulationEvent copyWith({
    String? id,
    SimulationEventType? type,
    String? message,
    String? affectedPokemonName,
    String? sourcePokemonName,
    String? moveName,
    int? damageAmount,
    int? hpBefore,
    int? hpAfter,
    int? maxHp,
    EventVariations? variations,
    EventModification? modification,
    bool? isEditable,
    bool? isModified,
    bool? needsRecalculation,
    BattleStateSnapshot? stateSnapshot,
  }) {
    return SimulationEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      affectedPokemonName: affectedPokemonName ?? this.affectedPokemonName,
      sourcePokemonName: sourcePokemonName ?? this.sourcePokemonName,
      moveName: moveName ?? this.moveName,
      damageAmount: damageAmount ?? this.damageAmount,
      hpBefore: hpBefore ?? this.hpBefore,
      hpAfter: hpAfter ?? this.hpAfter,
      maxHp: maxHp ?? this.maxHp,
      variations: variations ?? this.variations,
      modification: modification ?? this.modification,
      isEditable: isEditable ?? this.isEditable,
      isModified: isModified ?? this.isModified,
      needsRecalculation: needsRecalculation ?? this.needsRecalculation,
      stateSnapshot: stateSnapshot ?? this.stateSnapshot,
    );
  }
}

/// Probability of knockout vs survival
class KnockoutProbability {
  final double knockoutChance;
  final double survivalChance;
  final bool willAlwaysKO;
  final bool willAlwaysSurvive;

  const KnockoutProbability({
    required this.knockoutChance,
    required this.survivalChance,
    required this.willAlwaysKO,
    required this.willAlwaysSurvive,
  });

  String getDisplayText() {
    if (willAlwaysKO) return '100% KO';
    if (willAlwaysSurvive) return '100% Survival';

    final koPercent = (knockoutChance * 100).toStringAsFixed(1);
    final survivalPercent = (survivalChance * 100).toStringAsFixed(1);

    if (knockoutChance > 0.5) {
      return '$koPercent% KO';
    } else {
      return '$survivalPercent% Survival';
    }
  }
}

/// Complete battle state snapshot for rollback
class BattleStateSnapshot {
  final Map<String, BattlePokemon> pokemonStates;
  final List<BattlePokemon> team1Field;
  final List<BattlePokemon> team2Field;
  final List<BattlePokemon> team1Bench;
  final List<BattlePokemon> team2Bench;
  final Map<String, dynamic> fieldConditions;

  const BattleStateSnapshot({
    required this.pokemonStates,
    required this.team1Field,
    required this.team2Field,
    required this.team1Bench,
    required this.team2Bench,
    required this.fieldConditions,
  });

  /// Create a deep copy of current battle state
  factory BattleStateSnapshot.capture({
    required Map<String, BattlePokemon> pokemonStates,
    required List<BattlePokemon> team1Field,
    required List<BattlePokemon> team2Field,
    required List<BattlePokemon> team1Bench,
    required List<BattlePokemon> team2Bench,
    required Map<String, dynamic> fieldConditions,
  }) {
    // Deep copy pokemon states
    final copiedStates = <String, BattlePokemon>{};
    for (final entry in pokemonStates.entries) {
      copiedStates[entry.key] = entry.value.copyWith();
    }

    return BattleStateSnapshot(
      pokemonStates: copiedStates,
      team1Field: team1Field.map((p) => p.copyWith()).toList(),
      team2Field: team2Field.map((p) => p.copyWith()).toList(),
      team1Bench: team1Bench.map((p) => p.copyWith()).toList(),
      team2Bench: team2Bench.map((p) => p.copyWith()).toList(),
      fieldConditions: Map<String, dynamic>.from(fieldConditions),
    );
  }
}
