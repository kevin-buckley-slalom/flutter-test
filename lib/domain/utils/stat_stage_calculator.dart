import 'package:championdex/domain/utils/battle_constants.dart';

/// Calculator for stat stage modifiers used in Pokémon battles.
///
/// Stat stages range from -6 to +6, affecting the effective value of stats during battle.
/// Each stage increases or decreases the stat by 50% of the base multiplier.
///
/// Formulas:
/// - Positive stages: multiplier = (2 + stage) / 2
///   - +1 = 3/2 = 1.5×
///   - +2 = 4/2 = 2.0×
///   - +6 = 8/2 = 4.0×
///
/// - Negative stages: multiplier = 2 / (2 + |stage|)
///   - -1 = 2/3 = 0.67×
///   - -2 = 2/4 = 0.5×
///   - -6 = 2/8 = 0.25×
///
/// References:
/// - https://bulbapedia.bulbagarden.net/wiki/Stat_modifier
/// - https://bulbapedia.bulbagarden.net/wiki/Stat#Stage_multipliers
class StatStageCalculator {
  /// Get the multiplier for a given stat stage
  ///
  /// Stat stages range from -6 (minimum) to +6 (maximum).
  /// Stage 0 represents no modification (1.0× multiplier).
  ///
  /// Examples:
  /// ```dart
  /// StatStageCalculator.getMultiplier(0);  // 1.0   (no change)
  /// StatStageCalculator.getMultiplier(1);  // 1.5   (Swords Dance)
  /// StatStageCalculator.getMultiplier(2);  // 2.0   (two Swords Dances)
  /// StatStageCalculator.getMultiplier(-1); // 0.67  (Intimidate)
  /// StatStageCalculator.getMultiplier(-2); // 0.5   (two Intimidates)
  /// StatStageCalculator.getMultiplier(6);  // 4.0   (maximum boost)
  /// StatStageCalculator.getMultiplier(-6); // 0.25  (maximum reduction)
  /// ```
  static double getMultiplier(int stage) {
    // Clamp stage to valid range
    stage = stage.clamp(minStatStage, maxStatStage);

    if (stage >= 0) {
      // Positive stages: (2 + stage) / 2
      // This simplifies to: 1 + (stage × 0.5)
      return 1.0 + (stage * statStageIncrement);
    } else {
      // Negative stages: 2 / (2 + |stage|)
      // This simplifies to: 1 / (1 + (|stage| × 0.5))
      return 1.0 / (1.0 + ((-stage) * statStageIncrement));
    }
  }

  /// Apply a stat stage modifier to a base stat value
  ///
  /// Multiplies the base stat by the appropriate stage multiplier and returns
  /// the modified value as an integer.
  ///
  /// Example:
  /// ```dart
  /// final boostedAttack = StatStageCalculator.applyStatStage(
  ///   baseStat: 300,
  ///   stage: 2,  // +2 from Swords Dance
  /// );
  /// // Returns 600 (300 × 2.0)
  /// ```
  static int applyStatStage({
    required int baseStat,
    required int stage,
  }) {
    final multiplier = getMultiplier(stage);
    return (baseStat * multiplier).floor();
  }

  /// Apply multiple stat stage changes and return the final stage
  ///
  /// Clamps the result to the valid range of -6 to +6.
  ///
  /// Example:
  /// ```dart
  /// int attackStage = 0;
  /// attackStage = StatStageCalculator.addStages(attackStage, 2);  // Swords Dance: +2
  /// attackStage = StatStageCalculator.addStages(attackStage, 1);  // +1 more
  /// // attackStage = 3
  ///
  /// attackStage = StatStageCalculator.addStages(attackStage, 5);  // Try to add 5 more
  /// // attackStage = 6 (capped at maximum)
  /// ```
  static int addStages(int currentStage, int stageChange) {
    return (currentStage + stageChange).clamp(minStatStage, maxStatStage);
  }

  /// Reset stat stages to 0 (used by moves like Haze or switching out)
  static int resetStage() {
    return 0;
  }

  /// Get a human-readable description of a stat stage
  ///
  /// Returns a string describing the current stage and its effect.
  ///
  /// Examples:
  /// ```dart
  /// StatStageCalculator.getStageDescription(0);   // "Normal (1.0×)"
  /// StatStageCalculator.getStageDescription(1);   // "+1 (1.5×)"
  /// StatStageCalculator.getStageDescription(-2);  // "-2 (0.5×)"
  /// StatStageCalculator.getStageDescription(6);   // "+6 (4.0×) Maximum"
  /// ```
  static String getStageDescription(int stage) {
    stage = stage.clamp(minStatStage, maxStatStage);
    final multiplier = getMultiplier(stage);
    final multiplierStr = multiplier.toStringAsFixed(2);

    if (stage == 0) {
      return 'Normal ($multiplierStr×)';
    } else if (stage > 0) {
      final suffix = stage == maxStatStage ? ' Maximum' : '';
      return '+$stage ($multiplierStr×)$suffix';
    } else {
      final suffix = stage == minStatStage ? ' Minimum' : '';
      return '$stage ($multiplierStr×)$suffix';
    }
  }

  /// Calculate the net stat stage change from a move or ability
  ///
  /// Some moves change multiple stages at once:
  /// - Swords Dance: +2 Attack
  /// - Belly Drum: +6 Attack (maximum)
  /// - Intimidate: -1 Attack to opponent
  /// - Tail Whip: -1 Defense to opponent
  /// - Draco Meteor: -2 Sp. Atk to user
  ///
  /// This method helps validate and apply these changes.
  static Map<String, int> applyMoveStageChanges({
    required Map<String, int> currentStages,
    required Map<String, int> stageChanges,
  }) {
    final newStages = Map<String, int>.from(currentStages);

    for (final stat in stageChanges.keys) {
      final change = stageChanges[stat]!;
      final currentStage = currentStages[stat] ?? 0;
      newStages[stat] = addStages(currentStage, change);
    }

    return newStages;
  }

  /// Check if a stat stage is at maximum (+6)
  static bool isMaxStage(int stage) {
    return stage >= maxStatStage;
  }

  /// Check if a stat stage is at minimum (-6)
  static bool isMinStage(int stage) {
    return stage <= minStatStage;
  }

  /// Calculate accuracy/evasion multiplier (uses different formula than other stats)
  ///
  /// Accuracy and evasion stages use a different multiplier system:
  /// - Positive stages: (3 + stage) / 3
  /// - Negative stages: 3 / (3 + |stage|)
  ///
  /// This makes accuracy/evasion changes less dramatic than other stats.
  ///
  /// Examples:
  /// ```dart
  /// StatStageCalculator.getAccuracyMultiplier(1);   // 1.33× (Double Team reduces this)
  /// StatStageCalculator.getAccuracyMultiplier(-1);  // 0.75× (Sand Attack effect)
  /// StatStageCalculator.getAccuracyMultiplier(6);   // 3.0×  (maximum)
  /// ```
  static double getAccuracyMultiplier(int stage) {
    // Clamp stage to valid range
    stage = stage.clamp(minStatStage, maxStatStage);

    if (stage >= 0) {
      // Positive stages: (3 + stage) / 3
      return (3.0 + stage) / 3.0;
    } else {
      // Negative stages: 3 / (3 + |stage|)
      return 3.0 / (3.0 + (-stage));
    }
  }

  /// Calculate the combined multiplier for accuracy vs evasion
  ///
  /// In battle, accuracy stages of the attacker and evasion stages of the defender
  /// both affect the final hit chance. This combines both effects.
  ///
  /// Example:
  /// ```dart
  /// final hitModifier = StatStageCalculator.calculateHitChanceMultiplier(
  ///   accuracyStage: 1,   // User used Hone Claws
  ///   evasionStage: 2,    // Opponent used Double Team twice
  /// );
  /// // Combines both effects to determine final hit chance
  /// ```
  static double calculateHitChanceMultiplier({
    required int accuracyStage,
    required int evasionStage,
  }) {
    final accuracyMultiplier = getAccuracyMultiplier(accuracyStage);
    // Evasion works inversely - higher evasion means lower hit chance
    final evasionMultiplier = getAccuracyMultiplier(-evasionStage);
    return accuracyMultiplier * evasionMultiplier;
  }
}
