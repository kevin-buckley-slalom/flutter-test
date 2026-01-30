import 'package:championdex/data/models/pokemon_stats.dart';
import 'package:championdex/data/models/nature.dart';
import 'package:championdex/domain/utils/battle_constants.dart';

/// Calculator for Pokémon stat values based on base stats, IVs, EVs, level, and nature.
///
/// Uses the main series stat calculation formulas introduced in Generation III:
/// - HP: floor(((2 × Base + IV + floor(EV/4)) × Level) / 100) + Level + 10
/// - Other stats: floor(((2 × Base + IV + floor(EV/4)) × Level) / 100 + 5) × Nature
///
/// Reference: https://bulbapedia.bulbagarden.net/wiki/Stat#Determination_of_stats
class PokemonStatCalculator {
  /// Calculate HP stat value
  ///
  /// Formula: floor(((2 × Base + IV + floor(EV/4)) × Level) / 100) + Level + 10
  ///
  /// Example:
  /// ```dart
  /// final hp = PokemonStatCalculator.calculateHpStat(
  ///   baseHp: 108,      // Snorlax base HP
  ///   iv: 31,           // Max IV
  ///   ev: 252,          // Max HP investment
  ///   level: 100,       // Level 100
  /// );
  /// // Returns 416 HP
  /// ```
  static int calculateHpStat({
    required int baseHp,
    required int iv,
    required int ev,
    required int level,
  }) {
    // Shedinja always has 1 HP regardless of stats
    if (baseHp == 1) {
      return 1;
    }

    final int evContribution = ev ~/ evDivisor;
    final int preLevel = (2 * baseHp) + iv + evContribution;
    final int hpValue =
        (preLevel * level) ~/ levelDivisor + level + hpLevelBonus;
    return hpValue;
  }

  /// Calculate non-HP stat value (Attack, Defense, Sp. Atk, Sp. Def, Speed)
  ///
  /// Formula: floor(((2 × Base + IV + floor(EV/4)) × Level) / 100 + 5) × Nature
  ///
  /// The nature parameter is optional. If provided, it modifies the final stat:
  /// - Boosted stats: ×1.1 (e.g., Adamant boosts Attack)
  /// - Reduced stats: ×0.9 (e.g., Adamant reduces Sp. Atk)
  /// - Neutral stats: ×1.0
  ///
  /// Example:
  /// ```dart
  /// final attack = PokemonStatCalculator.calculateStat(
  ///   baseStat: 134,              // Garchomp base Attack
  ///   iv: 31,                     // Max IV
  ///   ev: 252,                    // Max Attack investment
  ///   level: 100,                 // Level 100
  ///   statName: 'attack',
  ///   nature: adamantNature,      // +Atk, -SpA
  /// );
  /// // Returns 394 Attack (359 × 1.1)
  /// ```
  static int calculateStat({
    required int baseStat,
    required int iv,
    required int ev,
    required int level,
    required String statName,
    Nature? nature,
  }) {
    final int evContribution = ev ~/ evDivisor;
    final int preLevel = (2 * baseStat) + iv + evContribution;
    int statValue = (preLevel * level) ~/ levelDivisor + statBaseBonus;

    // Apply nature modifier if provided
    if (nature != null) {
      final double natureMultiplier = nature.getMultiplierForStat(statName);
      statValue = (statValue * natureMultiplier).floor();
    }

    return statValue;
  }

  /// Calculate all stats for a Pokémon and return as PokemonStats object
  ///
  /// Convenience method that calculates all 6 stats at once.
  ///
  /// Example:
  /// ```dart
  /// final stats = PokemonStatCalculator.calculateAllStats(
  ///   baseStats: PokemonStats(total: 540, hp: 80, attack: 82, ...),
  ///   ivs: PokemonStats(total: 186, hp: 31, attack: 31, ...),
  ///   evs: PokemonStats(total: 510, hp: 252, attack: 252, ...),
  ///   level: 50,
  ///   nature: jollyNature,
  /// );
  /// // Returns calculated battle stats
  /// ```
  static PokemonStats calculateAllStats({
    required PokemonStats baseStats,
    required PokemonStats ivs,
    required PokemonStats evs,
    required int level,
    Nature? nature,
  }) {
    final hp = calculateHpStat(
      baseHp: baseStats.hp,
      iv: ivs.hp,
      ev: evs.hp,
      level: level,
    );

    final attack = calculateStat(
      baseStat: baseStats.attack,
      iv: ivs.attack,
      ev: evs.attack,
      level: level,
      statName: 'attack',
      nature: nature,
    );

    final defense = calculateStat(
      baseStat: baseStats.defense,
      iv: ivs.defense,
      ev: evs.defense,
      level: level,
      statName: 'defense',
      nature: nature,
    );

    final spAtk = calculateStat(
      baseStat: baseStats.spAtk,
      iv: ivs.spAtk,
      ev: evs.spAtk,
      level: level,
      statName: 'sp_atk',
      nature: nature,
    );

    final spDef = calculateStat(
      baseStat: baseStats.spDef,
      iv: ivs.spDef,
      ev: evs.spDef,
      level: level,
      statName: 'sp_def',
      nature: nature,
    );

    final speed = calculateStat(
      baseStat: baseStats.speed,
      iv: ivs.speed,
      ev: evs.speed,
      level: level,
      statName: 'speed',
      nature: nature,
    );

    final total = hp + attack + defense + spAtk + spDef + speed;

    return PokemonStats(
      total: total,
      hp: hp,
      attack: attack,
      defense: defense,
      spAtk: spAtk,
      spDef: spDef,
      speed: speed,
    );
  }

  /// Validate that EVs are within legal limits
  ///
  /// Rules:
  /// - Each individual EV must be 0-252
  /// - Total EVs across all stats must not exceed 510
  ///
  /// Returns null if valid, otherwise returns error message
  static String? validateEvs(PokemonStats evs) {
    // Check individual EV limits
    final evValues = [
      evs.hp,
      evs.attack,
      evs.defense,
      evs.spAtk,
      evs.spDef,
      evs.speed
    ];
    for (final ev in evValues) {
      if (ev < 0 || ev > maxEvValue) {
        return 'Each EV must be between 0 and $maxEvValue';
      }
    }

    // Check total EV limit
    if (evs.total > maxTotalEvs) {
      return 'Total EVs (${evs.total}) exceed maximum of $maxTotalEvs';
    }

    return null; // Valid
  }

  /// Validate that IVs are within legal limits (0-31 for each stat)
  ///
  /// Returns null if valid, otherwise returns error message
  static String? validateIvs(PokemonStats ivs) {
    final ivValues = [
      ivs.hp,
      ivs.attack,
      ivs.defense,
      ivs.spAtk,
      ivs.spDef,
      ivs.speed
    ];
    for (final iv in ivValues) {
      if (iv < 0 || iv > maxIvValue) {
        return 'Each IV must be between 0 and $maxIvValue';
      }
    }

    return null; // Valid
  }

  /// Calculate the minimum possible value for a stat
  ///
  /// Assumes 0 IVs, 0 EVs, and hindering nature (×0.9)
  static int calculateMinStat({
    required int baseStat,
    required int level,
    required String statName,
    bool isHp = false,
  }) {
    if (isHp) {
      return calculateHpStat(baseHp: baseStat, iv: 0, ev: 0, level: level);
    }

    // Use 0.9 multiplier for hindering nature
    final int preNature =
        ((2 * baseStat) * level) ~/ levelDivisor + statBaseBonus;
    return (preNature * 0.9).floor();
  }

  /// Calculate the maximum possible value for a stat
  ///
  /// Assumes 31 IVs, 252 EVs, and boosting nature (×1.1)
  static int calculateMaxStat({
    required int baseStat,
    required int level,
    required String statName,
    bool isHp = false,
  }) {
    if (isHp) {
      return calculateHpStat(
          baseHp: baseStat, iv: maxIvValue, ev: maxEvValue, level: level);
    }

    // Use 1.1 multiplier for boosting nature
    final int evContribution = maxEvValue ~/ evDivisor;
    final int preLevel = (2 * baseStat) + maxIvValue + evContribution;
    final int preNature = (preLevel * level) ~/ levelDivisor + statBaseBonus;
    return (preNature * 1.1).floor();
  }

  /// Calculate stat value at a specific level without IVs/EVs (for wild Pokémon)
  ///
  /// Uses average IVs (15-16) and no EVs for a realistic wild Pokémon stat
  static int calculateWildPokemonStat({
    required int baseStat,
    required int level,
    required String statName,
    bool isHp = false,
  }) {
    const averageIv = 15;
    const wildEv = 0;

    if (isHp) {
      return calculateHpStat(
        baseHp: baseStat,
        iv: averageIv,
        ev: wildEv,
        level: level,
      );
    }

    return calculateStat(
      baseStat: baseStat,
      iv: averageIv,
      ev: wildEv,
      level: level,
      statName: statName,
      nature: null, // Neutral nature
    );
  }
}
