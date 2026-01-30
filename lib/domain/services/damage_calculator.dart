import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/data/models/move.dart';

/// Result of a damage calculation including range and hit chance
class DamageResult {
  final int minDamage;
  final int maxDamage;
  final double hitChance; // 0.0 to 1.0
  final bool isCriticalChance;
  final String?
      effectivenessString; // "super-effective", "not very effective", etc
  final bool isTypeImmune;

  DamageResult({
    required this.minDamage,
    required this.maxDamage,
    required this.hitChance,
    required this.isCriticalChance,
    this.effectivenessString,
    required this.isTypeImmune,
  });

  int get averageDamage => ((minDamage + maxDamage) / 2).toInt();

  double get damagePercentage => (averageDamage / maxDamage).clamp(0.0, 1.0);
}

/// Calculates damage for moves considering all modifiers and stat stages
class DamageCalculator {
  static const double stabMultiplier = 1.5;
  static const double criticalMultiplier = 1.5;
  static const int baseRandomFactor = 85; // min damage is 85/100 of calculated
  static const int maxRandomFactor = 100; // max damage is 100/100 of calculated

  /// Calculate damage for a move against a target
  static DamageResult calculateDamage({
    required BattlePokemon attacker,
    required BattlePokemon defender,
    required Move move,
    required List<String> attackerTypes,
    required List<String> defenderTypes,
  }) {
    // Status moves do no damage
    if (move.category == 'Status') {
      return DamageResult(
        minDamage: 0,
        maxDamage: 0,
        hitChance: 1.0,
        isCriticalChance: false,
        isTypeImmune: false,
      );
    }

    // Check if type is immune
    final effectiveness = _getTypeEffectiveness(move.type, defenderTypes);
    if (effectiveness == 0.0) {
      return DamageResult(
        minDamage: 0,
        maxDamage: 0,
        hitChance: 1.0,
        isCriticalChance: false,
        effectivenessString: 'immune',
        isTypeImmune: true,
      );
    }

    // Calculate base damage
    int baseDamage = move.power ?? 0;
    if (baseDamage == 0) {
      return DamageResult(
        minDamage: 0,
        maxDamage: 0,
        hitChance: 1.0,
        isCriticalChance: false,
        isTypeImmune: false,
      );
    }

    // Determine attack and defense stats
    final useSpecial = move.category == 'Special';
    final atkStat = useSpecial
        ? attacker.stats?.spAtk ?? 100
        : attacker.stats?.attack ?? 100;
    final defStat = useSpecial
        ? defender.stats?.spDef ?? 100
        : defender.stats?.defense ?? 100;

    // Apply stat stages
    final atkStage = attacker.statStages[useSpecial ? 'spa' : 'atk'] ?? 0;
    final defStage = defender.statStages[useSpecial ? 'spd' : 'def'] ?? 0;

    final effectiveAtk = (atkStat * _getStatMultiplier(atkStage)).toInt();
    final effectiveDef = (defStat * _getStatMultiplier(defStage)).toInt();

    // Calculate raw damage using Gen V+ formula:
    // (((2 * Level / 5 + 2) * Power * Attack / Defense) / 50 + 2)
    double damageCalc = ((2 * attacker.level / 5.0 + 2) *
                baseDamage *
                effectiveAtk /
                effectiveDef) /
            50.0 +
        2;

    // Apply STAB (Same Type Attack Bonus)
    if (attackerTypes.contains(move.type)) {
      damageCalc *= stabMultiplier;
    }

    // Apply type effectiveness
    damageCalc *= effectiveness;

    // Apply ability modifiers
    damageCalc *= _getAbilityDamageModifier(attacker, defender, move);

    // Apply item modifiers
    damageCalc *= _getItemDamageModifier(attacker, defender, move);

    // Apply weather modifiers
    damageCalc *= _getWeatherDamageModifier(move);

    // Convert to int
    int calculatedDamage = damageCalc.toInt().clamp(1, defender.maxHp);

    // Calculate range with variance
    int minDamage = ((calculatedDamage * baseRandomFactor) / 100)
        .toInt()
        .clamp(1, calculatedDamage);
    int maxDamage = calculatedDamage;

    // Hit accuracy
    double hitChance = _calculateHitChance(
      move.accuracy ?? 100,
      attacker.statStages['acc'] ?? 0,
      defender.statStages['eva'] ?? 0,
    );

    // Determine effectiveness string
    String? effectivenessString;
    if (effectiveness > 1.0) {
      effectivenessString = 'super-effective';
    } else if (effectiveness < 1.0) {
      effectivenessString = 'not-very-effective';
    }

    // Critical hit chance (simplified: 1/16 base chance)
    bool isCriticalChance = true; // TODO: calculate actual crit chance

    return DamageResult(
      minDamage: minDamage,
      maxDamage: maxDamage,
      hitChance: hitChance,
      isCriticalChance: isCriticalChance,
      effectivenessString: effectivenessString,
      isTypeImmune: false,
    );
  }

  /// Get stat multiplier for a given stat stage
  static double _getStatMultiplier(int stage) {
    if (stage >= 0) {
      return 1 + (stage * 0.5);
    } else {
      return 1 / (1 + ((-stage) * 0.5));
    }
  }

  /// Calculate hit accuracy considering move accuracy and stat stages
  static double _calculateHitChance(
    int moveAccuracy,
    int accuracyStage,
    int evasionStage,
  ) {
    // Clamp stages to -6 to +6
    accuracyStage = accuracyStage.clamp(-6, 6);
    evasionStage = evasionStage.clamp(-6, 6);

    double baseAccuracy = moveAccuracy / 100.0;

    // Apply accuracy/evasion stages
    double accuracyMultiplier = _getStatMultiplier(accuracyStage);
    double evasionMultiplier = _getStatMultiplier(-evasionStage);

    double finalAccuracy =
        baseAccuracy * accuracyMultiplier * evasionMultiplier;
    return finalAccuracy.clamp(0.0, 1.0);
  }

  /// Get damage modifier from attacker's ability
  static double _getAbilityDamageModifier(
    BattlePokemon attacker,
    BattlePokemon defender,
    Move move,
  ) {
    final ability = attacker.ability;
    if (ability == null) return 1.0;

    // Common ability modifiers
    switch (ability.toLowerCase()) {
      // Damage boosting abilities
      case 'adaptability':
        // If STAB would apply, boost is 2x instead of 1.5x (additional 1.33x multiplier)
        return 1.0; // Already handled in STAB calculation
      case 'huge power':
      case 'pure power':
        // Doubles attack stat
        return 2.0;
      case 'dragon maw':
        // Dragon-type moves get 1.5x
        if (move.type == 'Dragon') return 1.5;
        break;
      case 'torrent':
      case 'blaze':
      case 'overgrow':
      case 'swarm':
        // Water/Fire/Grass/Bug moves get 1.5x when at low HP
        // TODO: Check if attacker HP is <= 1/3
        return 1.5;
      case 'tough claws':
        // Contact moves get 1.33x
        if (move.makesContact == true) return 1.33;
        break;
    }

    return 1.0;
  }

  /// Get damage modifier from attacker's item
  static double _getItemDamageModifier(
    BattlePokemon attacker,
    BattlePokemon defender,
    Move move,
  ) {
    final item = attacker.item;
    if (item == null) return 1.0;

    // Common item modifiers
    switch (item.toLowerCase()) {
      case 'choice band':
        // 1.5x physical moves
        if (move.category == 'Physical') return 1.5;
        break;
      case 'choice specs':
        // 1.5x special moves
        if (move.category == 'Special') return 1.5;
        break;
      case 'light ball':
        // Pikachu gets 1x damage with all moves (actually 2x attack/spA)
        // For now, simplified to physical/special boost
        return 2.0;
        break;
      case 'thick club':
        // Cubone/Marowak get 1x damage boost (actually 2x attack/defense)
        return 2.0;
        break;
      case 'assault vest':
        // Doesn't boost damage, only reduces special damage taken
        break;
      case 'weakness policy':
        // 1.5x boost after taking SE damage (not yet hit)
        break;
    }

    return 1.0;
  }

  /// Get damage modifier from weather
  static double _getWeatherDamageModifier(Move move) {
    // TODO: Implement when weather is available in battle state
    // Rain boosts Water moves by 1.5x
    // Sun boosts Fire moves by 1.5x, reduces Water by 0.5x
    // Hail/Sand affect certain types
    return 1.0;
  }

  /// Calculate type effectiveness against multiple defender types
  static double _getTypeEffectiveness(
      String attackingType, List<String> defenderTypes) {
    // Get effectiveness against each defending type and multiply
    double multiplier = 1.0;

    for (final defendingType in defenderTypes) {
      final typeMultiplier = _typeChartLookup(attackingType, defendingType);
      multiplier *= typeMultiplier;
    }

    return multiplier;
  }

  /// Direct type chart lookup
  static double _typeChartLookup(String attackingType, String defendingType) {
    const typeChart = {
      'Normal': {
        'Normal': 1.0,
        'Fire': 1.0,
        'Water': 1.0,
        'Electric': 1.0,
        'Grass': 1.0,
        'Ice': 1.0,
        'Fighting': 1.0,
        'Poison': 1.0,
        'Ground': 1.0,
        'Flying': 1.0,
        'Psychic': 1.0,
        'Bug': 1.0,
        'Rock': 0.5,
        'Ghost': 0.0,
        'Dragon': 1.0,
        'Dark': 1.0,
        'Steel': 0.5,
        'Fairy': 1.0,
      },
      'Fire': {
        'Normal': 1.0,
        'Fire': 0.5,
        'Water': 0.5,
        'Electric': 1.0,
        'Grass': 2.0,
        'Ice': 2.0,
        'Fighting': 1.0,
        'Poison': 1.0,
        'Ground': 1.0,
        'Flying': 1.0,
        'Psychic': 1.0,
        'Bug': 2.0,
        'Rock': 0.5,
        'Ghost': 1.0,
        'Dragon': 0.5,
        'Dark': 1.0,
        'Steel': 2.0,
        'Fairy': 1.0,
      },
      'Water': {
        'Normal': 1.0,
        'Fire': 2.0,
        'Water': 0.5,
        'Electric': 1.0,
        'Grass': 0.5,
        'Ice': 1.0,
        'Fighting': 1.0,
        'Poison': 1.0,
        'Ground': 2.0,
        'Flying': 1.0,
        'Psychic': 1.0,
        'Bug': 1.0,
        'Rock': 2.0,
        'Ghost': 1.0,
        'Dragon': 0.5,
        'Dark': 1.0,
        'Steel': 1.0,
        'Fairy': 1.0,
      },
      'Electric': {
        'Normal': 1.0,
        'Fire': 1.0,
        'Water': 2.0,
        'Electric': 0.5,
        'Grass': 0.5,
        'Ice': 1.0,
        'Fighting': 1.0,
        'Poison': 1.0,
        'Ground': 0.0,
        'Flying': 2.0,
        'Psychic': 1.0,
        'Bug': 1.0,
        'Rock': 1.0,
        'Ghost': 1.0,
        'Dragon': 0.5,
        'Dark': 1.0,
        'Steel': 1.0,
        'Fairy': 1.0,
      },
      'Grass': {
        'Normal': 1.0,
        'Fire': 0.5,
        'Water': 2.0,
        'Electric': 1.0,
        'Grass': 0.5,
        'Ice': 1.0,
        'Fighting': 1.0,
        'Poison': 0.5,
        'Ground': 2.0,
        'Flying': 0.5,
        'Psychic': 1.0,
        'Bug': 0.5,
        'Rock': 2.0,
        'Ghost': 1.0,
        'Dragon': 0.5,
        'Dark': 1.0,
        'Steel': 0.5,
        'Fairy': 1.0,
      },
      'Ice': {
        'Normal': 1.0,
        'Fire': 0.5,
        'Water': 0.5,
        'Electric': 1.0,
        'Grass': 2.0,
        'Ice': 0.5,
        'Fighting': 1.0,
        'Poison': 1.0,
        'Ground': 2.0,
        'Flying': 2.0,
        'Psychic': 1.0,
        'Bug': 1.0,
        'Rock': 1.0,
        'Ghost': 1.0,
        'Dragon': 2.0,
        'Dark': 1.0,
        'Steel': 0.5,
        'Fairy': 1.0,
      },
      'Fighting': {
        'Normal': 2.0,
        'Fire': 1.0,
        'Water': 1.0,
        'Electric': 1.0,
        'Grass': 1.0,
        'Ice': 2.0,
        'Fighting': 1.0,
        'Poison': 0.5,
        'Ground': 1.0,
        'Flying': 0.5,
        'Psychic': 0.5,
        'Bug': 0.5,
        'Rock': 2.0,
        'Ghost': 0.0,
        'Dragon': 1.0,
        'Dark': 2.0,
        'Steel': 2.0,
        'Fairy': 0.5,
      },
      'Poison': {
        'Normal': 1.0,
        'Fire': 1.0,
        'Water': 1.0,
        'Electric': 1.0,
        'Grass': 2.0,
        'Ice': 1.0,
        'Fighting': 1.0,
        'Poison': 0.5,
        'Ground': 0.5,
        'Flying': 1.0,
        'Psychic': 1.0,
        'Bug': 1.0,
        'Rock': 0.5,
        'Ghost': 0.5,
        'Dragon': 1.0,
        'Dark': 1.0,
        'Steel': 0.0,
        'Fairy': 2.0,
      },
      'Ground': {
        'Normal': 1.0,
        'Fire': 2.0,
        'Water': 1.0,
        'Electric': 2.0,
        'Grass': 0.5,
        'Ice': 1.0,
        'Fighting': 1.0,
        'Poison': 2.0,
        'Ground': 1.0,
        'Flying': 0.0,
        'Psychic': 1.0,
        'Bug': 0.5,
        'Rock': 2.0,
        'Ghost': 1.0,
        'Dragon': 1.0,
        'Dark': 1.0,
        'Steel': 2.0,
        'Fairy': 1.0,
      },
      'Flying': {
        'Normal': 1.0,
        'Fire': 1.0,
        'Water': 1.0,
        'Electric': 0.5,
        'Grass': 2.0,
        'Ice': 1.0,
        'Fighting': 2.0,
        'Poison': 1.0,
        'Ground': 1.0,
        'Flying': 1.0,
        'Psychic': 1.0,
        'Bug': 2.0,
        'Rock': 0.5,
        'Ghost': 1.0,
        'Dragon': 1.0,
        'Dark': 1.0,
        'Steel': 0.5,
        'Fairy': 1.0,
      },
      'Psychic': {
        'Normal': 1.0,
        'Fire': 1.0,
        'Water': 1.0,
        'Electric': 1.0,
        'Grass': 1.0,
        'Ice': 1.0,
        'Fighting': 2.0,
        'Poison': 2.0,
        'Ground': 1.0,
        'Flying': 1.0,
        'Psychic': 0.5,
        'Bug': 1.0,
        'Rock': 1.0,
        'Ghost': 1.0,
        'Dragon': 1.0,
        'Dark': 0.0,
        'Steel': 0.5,
        'Fairy': 1.0,
      },
      'Bug': {
        'Normal': 0.5,
        'Fire': 0.5,
        'Water': 1.0,
        'Electric': 1.0,
        'Grass': 2.0,
        'Ice': 1.0,
        'Fighting': 0.5,
        'Poison': 0.5,
        'Ground': 1.0,
        'Flying': 0.5,
        'Psychic': 2.0,
        'Bug': 1.0,
        'Rock': 1.0,
        'Ghost': 0.5,
        'Dragon': 1.0,
        'Dark': 1.0,
        'Steel': 0.5,
        'Fairy': 0.5,
      },
      'Rock': {
        'Normal': 0.5,
        'Fire': 2.0,
        'Water': 1.0,
        'Electric': 1.0,
        'Grass': 1.0,
        'Ice': 2.0,
        'Fighting': 0.5,
        'Poison': 1.0,
        'Ground': 0.5,
        'Flying': 2.0,
        'Psychic': 1.0,
        'Bug': 2.0,
        'Rock': 1.0,
        'Ghost': 1.0,
        'Dragon': 1.0,
        'Dark': 1.0,
        'Steel': 0.5,
        'Fairy': 1.0,
      },
      'Ghost': {
        'Normal': 0.0,
        'Fire': 1.0,
        'Water': 1.0,
        'Electric': 1.0,
        'Grass': 1.0,
        'Ice': 1.0,
        'Fighting': 1.0,
        'Poison': 1.0,
        'Ground': 1.0,
        'Flying': 1.0,
        'Psychic': 2.0,
        'Bug': 1.0,
        'Rock': 1.0,
        'Ghost': 2.0,
        'Dragon': 1.0,
        'Dark': 0.5,
        'Steel': 1.0,
        'Fairy': 1.0,
      },
      'Dragon': {
        'Normal': 1.0,
        'Fire': 1.0,
        'Water': 1.0,
        'Electric': 1.0,
        'Grass': 1.0,
        'Ice': 1.0,
        'Fighting': 1.0,
        'Poison': 1.0,
        'Ground': 1.0,
        'Flying': 1.0,
        'Psychic': 1.0,
        'Bug': 1.0,
        'Rock': 1.0,
        'Ghost': 1.0,
        'Dragon': 2.0,
        'Dark': 1.0,
        'Steel': 0.5,
        'Fairy': 0.0,
      },
      'Dark': {
        'Normal': 1.0,
        'Fire': 1.0,
        'Water': 1.0,
        'Electric': 1.0,
        'Grass': 1.0,
        'Ice': 1.0,
        'Fighting': 0.5,
        'Poison': 1.0,
        'Ground': 1.0,
        'Flying': 1.0,
        'Psychic': 2.0,
        'Bug': 1.0,
        'Rock': 1.0,
        'Ghost': 2.0,
        'Dragon': 1.0,
        'Dark': 0.5,
        'Steel': 1.0,
        'Fairy': 0.5,
      },
      'Steel': {
        'Normal': 0.5,
        'Fire': 0.5,
        'Water': 0.5,
        'Electric': 0.5,
        'Grass': 2.0,
        'Ice': 2.0,
        'Fighting': 1.0,
        'Poison': 0.0,
        'Ground': 1.0,
        'Flying': 0.5,
        'Psychic': 0.5,
        'Bug': 2.0,
        'Rock': 2.0,
        'Ghost': 1.0,
        'Dragon': 1.0,
        'Dark': 1.0,
        'Steel': 0.5,
        'Fairy': 2.0,
      },
      'Fairy': {
        'Normal': 1.0,
        'Fire': 0.5,
        'Water': 1.0,
        'Electric': 1.0,
        'Grass': 1.0,
        'Ice': 1.0,
        'Fighting': 2.0,
        'Poison': 0.5,
        'Ground': 1.0,
        'Flying': 1.0,
        'Psychic': 1.0,
        'Bug': 1.0,
        'Rock': 1.0,
        'Ghost': 1.0,
        'Dragon': 2.0,
        'Dark': 2.0,
        'Steel': 0.5,
        'Fairy': 1.0,
      },
    };

    return typeChart[attackingType]?[defendingType] ?? 1.0;
  }
}
