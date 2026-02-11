import 'package:championdex/domain/battle/simulation_event.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/data/models/move.dart';
import 'package:uuid/uuid.dart';

enum EffectTiming {
  /// Before move resolves (e.g., Trick Room, Reflect)
  immediate,

  /// After damage calculated but before HP modification
  afterDamage,

  /// After all actions in current turn
  endOfTurn,

  /// After each individual hit in multi-hit moves
  afterHit,
}

/// Base class for all structured move effects
///
/// Instead of parsing natural language effect strings, each move effect is
/// represented as a structured object with clear semantics. This allows:
/// - Context-aware handling (knowing actual damage dealt)
/// - Ability/item interaction support
/// - Proper multi-hit integration
/// - Type safety
///
/// Effects are responsible for:
/// 1. Checking ability/item modifiers
/// 2. Applying HP/stat changes with proper validation
/// 3. Generating SimulationEvents for logging
/// 4. Handling multi-hit scenarios correctly
abstract class MoveEffect {
  /// When this effect applies relative to damage
  EffectTiming get timing => EffectTiming.afterDamage;

  /// Whether this effect applies once or per hit for multi-hit moves
  bool get triggersPerHit => false;

  /// Apply this effect to the battle state
  ///
  /// [attacker] - The Pokémon that used the move
  /// [defender] - The Pokémon being hit by the move
  /// [move] - The move being used (for reference data)
  /// [damageDealt] - The damage dealt by this hit (0 if miss)
  /// [events] - List to append SimulationEvents to
  void apply(
    BattlePokemon attacker,
    BattlePokemon defender,
    Move move,
    int damageDealt,
    List<SimulationEvent> events,
  );

  /// Human-readable description of this effect for debugging
  String get description;
}

/// Effect that heals the user based on damage dealt (drain moves)
///
/// Examples: Absorb (50%), Drain Punch (50%), Giga Drain (50%), Leech Life (50%)
///
/// Interactions:
/// - Big Root item increases healing by 30% (multiplicative)
/// - Liquid Ooze ability reverses effect (attacker loses HP instead)
class DrainHealingEffect extends MoveEffect {
  /// Percentage of damage to heal (e.g., 0.50 for 50%)
  final double drainPercent;

  /// Whether the healing is guaranteed (true) or probabilistic
  final bool isGuaranteed;

  /// Percentage chance to trigger if not guaranteed (0-100)
  final double probabilityPercent;

  DrainHealingEffect({
    required this.drainPercent,
    this.isGuaranteed = true,
    this.probabilityPercent = 100.0,
  });

  @override
  EffectTiming get timing => EffectTiming.afterDamage;

  @override
  bool get triggersPerHit => true;

  @override
  String get description =>
      'Drains ${(drainPercent * 100).toInt()}% of damage dealt as HP';

  @override
  void apply(
    BattlePokemon attacker,
    BattlePokemon defender,
    Move move,
    int damageDealt,
    List<SimulationEvent> events,
  ) {
    // If no damage dealt, no healing
    if (damageDealt <= 0) return;

    // Check if effect triggers (for probabilistic effects)
    if (!isGuaranteed) {
      if (DateTime.now().millisecond % 100 > probabilityPercent) {
        return; // Effect missed its probability check
      }
    }

    // Calculate base healing amount
    int healAmount = (damageDealt * drainPercent).toInt();

    // Check for Liquid Ooze ability reversal
    if (defender.ability == 'Liquid Ooze') {
      // Reverse effect: attacker loses HP instead
      final lossAmount = healAmount;
      final actualLoss = lossAmount.clamp(1, attacker.currentHp - 1);
      attacker.currentHp -= actualLoss;

      events.add(SimulationEvent(
        id: const Uuid().v4(),
        message:
            "${attacker.pokemonName} lost $actualLoss HP due to Liquid Ooze!",
        type: SimulationEventType.statusApplied,
        affectedPokemonName: attacker.originalName,
      ));
      return;
    }

    // Apply Big Root item modifier
    if (attacker.item == 'Big Root') {
      healAmount = (healAmount * 1.30).toInt(); // 30% increase
    }

    // Cap healing to max HP
    final actualHeal = healAmount.clamp(0, attacker.maxHp - attacker.currentHp);

    if (actualHeal > 0) {
      attacker.currentHp += actualHeal;

      final itemBonus = attacker.item == 'Big Root' ? ' (Big Root)' : '';
      events.add(SimulationEvent(
        id: const Uuid().v4(),
        message: '${attacker.pokemonName} recovered $actualHeal HP!$itemBonus',
        type: SimulationEventType.statusApplied,
        affectedPokemonName: attacker.originalName,
      ));
    }
  }
}

/// Effect that applies a status condition to the defender
///
/// Examples: Thunder Wave (paralysis), Will-O-Wisp (burn), Toxic (badly poisoned)
class StatusConditionEffect extends MoveEffect {
  /// The status condition to apply (e.g., 'burn', 'paralysis', 'poison')
  final String statusCondition;

  /// Whether the status is guaranteed (true) or probabilistic
  final bool isGuaranteed;

  /// Percentage chance to trigger if not guaranteed (0-100)
  final double probabilityPercent;

  StatusConditionEffect({
    required this.statusCondition,
    this.isGuaranteed = true,
    this.probabilityPercent = 100.0,
  });

  @override
  EffectTiming get timing => EffectTiming.afterDamage;

  @override
  bool get triggersPerHit => true;

  @override
  String get description => 'May apply $statusCondition';

  @override
  void apply(
    BattlePokemon attacker,
    BattlePokemon defender,
    Move move,
    int damageDealt,
    List<SimulationEvent> events,
  ) {
    // Probabilistic effects need a random roll
    if (!isGuaranteed) {
      if (DateTime.now().millisecond % 100 > probabilityPercent) {
        return; // Effect missed its probability check
      }
    }

    // Check if defender has immunity ability
    if (_abilityPreventsStatus(defender.ability, statusCondition)) {
      events.add(SimulationEvent(
        id: const Uuid().v4(),
        message:
            "${defender.pokemonName}'s ${defender.ability} prevents status!",
        type: SimulationEventType.statusApplied,
        affectedPokemonName: defender.originalName,
      ));
      return;
    }

    // Check if already has this status
    if (defender.status == statusCondition) {
      return; // Already afflicted
    }

    // Apply the status condition
    defender.status = statusCondition;

    events.add(SimulationEvent(
      id: const Uuid().v4(),
      message:
          '${defender.pokemonName} is now ${statusCondition.toLowerCase()}!',
      type: SimulationEventType.statusApplied,
      affectedPokemonName: defender.originalName,
    ));
  }

  // Helper to check if ability prevents a status
  bool _abilityPreventsStatus(String? ability, String status) {
    if (ability == null) return false;

    // Map abilities that prevent specific statuses
    const preventionMap = {
      'paralysis': ['Limber'],
      'burn': ['Water Absorb', 'Comatose'],
      'poison': ['Immunity'],
      'sleep': ['Insomnia', 'Vital Spirit'],
      'freeze': ['Magma Armor'],
      'confusion': ['Oblivious'],
    };

    return preventionMap[status]?.contains(ability) ?? false;
  }
}

/// Effect that modifies the defender's stats
///
/// Examples: Dragon Dance (raises Atk/Spe), Growl (lowers Atk)
class StatChangeEffect extends MoveEffect {
  /// Stat changes to apply: {'attack': -1, 'speed': -2}
  final Map<String, int> statChanges;

  /// Whether this affects the attacker (true) or defender (false)
  final bool affectsAttacker;

  /// Whether changes are guaranteed or probabilistic
  final bool isGuaranteed;

  /// Percentage chance if not guaranteed
  final double probabilityPercent;

  StatChangeEffect({
    required this.statChanges,
    this.affectsAttacker = false,
    this.isGuaranteed = true,
    this.probabilityPercent = 100.0,
  });

  @override
  EffectTiming get timing => EffectTiming.afterDamage;

  @override
  String get description {
    final changes = statChanges.entries.map((e) {
      final direction = e.value > 0 ? '+' : '';
      return '${e.key} $direction${e.value}';
    }).join(', ');
    return 'Changes stats: $changes';
  }

  @override
  void apply(
    BattlePokemon attacker,
    BattlePokemon defender,
    Move move,
    int damageDealt,
    List<SimulationEvent> events,
  ) {
    // Probabilistic effects need a roll
    if (!isGuaranteed) {
      if (DateTime.now().millisecond % 100 > probabilityPercent) {
        return;
      }
    }

    // For now, this is a placeholder since BattlePokemon doesn't have stat modifiers
    // This will be implemented when the battle system fully integrates
  }
}

/// Effect that causes flinching
///
/// Example: Flinch Punch, Fake Out
class FlinchEffect extends MoveEffect {
  /// Percentage chance to flinch (0-100)
  final double probabilityPercent;

  FlinchEffect({this.probabilityPercent = 100.0});

  @override
  EffectTiming get timing => EffectTiming.afterDamage;

  @override
  bool get triggersPerHit => true;

  @override
  String get description =>
      'May cause flinch (${probabilityPercent.toInt()}% chance)';

  @override
  void apply(
    BattlePokemon attacker,
    BattlePokemon defender,
    Move move,
    int damageDealt,
    List<SimulationEvent> events,
  ) {
    // Flinch only works if damage was dealt
    if (damageDealt <= 0) return;

    // Check probability
    if (DateTime.now().millisecond % 100 > probabilityPercent) {
      return;
    }

    // Check Inner Focus ability
    if (defender.ability == 'Inner Focus') {
      events.add(SimulationEvent(
        id: const Uuid().v4(),
        message: "${defender.pokemonName}'s Inner Focus prevents flinch!",
        type: SimulationEventType.statusApplied,
        affectedPokemonName: defender.originalName,
      ));
      return;
    }

    // Apply flinch
    defender.volatileStatus['flinch'] = true;

    events.add(SimulationEvent(
      id: const Uuid().v4(),
      message: '${defender.pokemonName} flinched!',
      type: SimulationEventType.statusApplied,
      affectedPokemonName: defender.originalName,
    ));
  }
}

/// Effect that causes confusion
///
/// Confusion is a volatile status condition that may cause the afflicted Pokémon
/// to damage itself instead of using its move. Lasts 1-4 turns randomly.
///
/// Examples:
/// - Damaging moves: Confusion (10%), Dynamic Punch (100%), Hurricane (30%)
/// - Status moves: Confuse Ray (100%), Supersonic (100%), Swagger (100%)
/// - Self-confusion: Outrage/Thrash/Petal Dance (after 2-3 turns, TODO)
///
/// Interactions:
/// - 33% chance per turn to hit itself with 40 BP typeless physical attack
/// - Blocked by Own Tempo ability
/// - Tangled Feet increases evasion while confused (TODO)
/// - Multi-turn moves (Outrage, Thrash, Petal Dance, Raging Fury) confuse user after attacking 2-3 turns (TODO)
class ConfusionEffect extends MoveEffect {
  /// Percentage chance to confuse (0-100)
  final double probabilityPercent;

  /// Whether this confuses the user (true) or the defender (false)
  /// Used for multi-turn move self-confusion (Outrage, Thrash, etc)
  final bool confusesUser;

  /// Optional condition that must be met for confusion to apply
  /// Example: "if_opponent_stat_boosted" for Alluring Voice
  final String? condition;

  ConfusionEffect({
    this.probabilityPercent = 100.0,
    this.confusesUser = false,
    this.condition,
  });

  @override
  EffectTiming get timing => EffectTiming.afterDamage;

  @override
  bool get triggersPerHit => true;

  @override
  String get description {
    final target = confusesUser ? 'user' : 'opponent';
    final chance = probabilityPercent < 100
        ? ' (${probabilityPercent.toInt()}% chance)'
        : '';
    final condText = condition != null ? ' [condition: $condition]' : '';
    return 'May confuse $target$chance$condText';
  }

  @override
  void apply(
    BattlePokemon attacker,
    BattlePokemon defender,
    Move move,
    int damageDealt,
    List<SimulationEvent> events,
  ) {
    final target = confusesUser ? attacker : defender;

    // For damaging moves, confusion only applies if damage was dealt
    if (move.category != 'Status' && damageDealt <= 0) return;

    // TODO: Multi-turn move self-confusion tracking
    // Moves like Outrage, Thrash, Petal Dance, and Raging Fury lock the user into
    // using that move for 2-3 turns, then confuse the user after attacking that many times.
    // Implementation requires:
    // 1. Detecting when these moves are used (check move name or new move flag)
    // 2. Setting multiturnMoveName and multiturnMoveTurnsRemaining on attacker
    // 3. Forcing the move to be used again next turn (restrict move choice)
    // 4. After final turn, apply confusion to the user (confusesUser = true)
    // 5. Reset multiturnMoveName and multiturnMoveTurnsRemaining
    // The existing BattlePokemon fields (multiturnMoveName, multiturnMoveTurnsRemaining)
    // can be used for this tracking.

    // Check condition if present
    if (condition == 'if_opponent_stat_boosted') {
      // TODO: Track whether opponent boosted stats this turn
      // For now, skip this condition check
      return;
    }

    // Check probability
    if (DateTime.now().millisecond % 100 > probabilityPercent) {
      return;
    }

    // Check Own Tempo ability
    if (target.ability == 'Own Tempo') {
      events.add(SimulationEvent(
        id: const Uuid().v4(),
        message: "${target.pokemonName}'s Own Tempo prevents confusion!",
        type: SimulationEventType.statusApplied,
        affectedPokemonName: target.originalName,
      ));
      return;
    }

    // Check if already confused
    if (target.volatileStatus['confused'] == true) {
      return; // Already confused
    }

    // Apply confusion with random duration (1-4 turns)
    target.volatileStatus['confused'] = true;
    final duration = 1 + (DateTime.now().millisecond % 4); // 1-4 turns
    target.volatileStatus['confusion_turns_remaining'] = duration;

    events.add(SimulationEvent(
      id: const Uuid().v4(),
      message: '${target.pokemonName} became confused!',
      type: SimulationEventType.statusApplied,
      affectedPokemonName: target.originalName,
      variations: EventVariations(
        effectProbability: probabilityPercent < 100 ? probabilityPercent : null,
        effectName: probabilityPercent < 100 ? 'confusion' : null,
      ),
    ));
  }
}

/// Effect that causes recoil damage to the user
///
/// Examples: Jump Kick (50% recoil if miss), Struggle (25% recoil)
class RecoilEffect extends MoveEffect {
  /// Percentage of damage dealt as recoil (e.g., 0.25 for 25%)
  final double recoilPercent;

  /// If true, recoil only applies on miss; if false, always applies
  final bool onlyOnMiss;

  RecoilEffect({
    required this.recoilPercent,
    this.onlyOnMiss = false,
  });

  @override
  EffectTiming get timing => EffectTiming.afterDamage;

  @override
  String get description =>
      'Causes ${(recoilPercent * 100).toInt()}% recoil damage';

  @override
  void apply(
    BattlePokemon attacker,
    BattlePokemon defender,
    Move move,
    int damageDealt,
    List<SimulationEvent> events,
  ) {
    // Skip if onlyOnMiss is true and damage was dealt
    if (onlyOnMiss && damageDealt > 0) return;

    // Calculate recoil amount
    final recoilAmount =
        (damageDealt * recoilPercent).toInt().clamp(1, attacker.currentHp - 1);

    attacker.currentHp -= recoilAmount;

    events.add(SimulationEvent(
      id: const Uuid().v4(),
      message: '${attacker.pokemonName} took $recoilAmount HP in recoil!',
      type: SimulationEventType.statusApplied,
      affectedPokemonName: attacker.originalName,
    ));
  }
}
