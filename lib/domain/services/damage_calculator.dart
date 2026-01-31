import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/domain/utils/battle_constants.dart';
import 'package:championdex/domain/utils/type_chart.dart';
import 'package:championdex/domain/utils/stat_stage_calculator.dart';

/// Field state tracking screen effects for both sides
class FieldState {
  final bool reflectActive;
  final bool lightScreenActive;
  final bool auroraVeilActive;
  final bool luckyChantActive;
  final int reflectTurnsRemaining;
  final int lightScreenTurnsRemaining;
  final int auroraVeilTurnsRemaining;

  const FieldState({
    this.reflectActive = false,
    this.lightScreenActive = false,
    this.auroraVeilActive = false,
    this.luckyChantActive = false,
    this.reflectTurnsRemaining = 0,
    this.lightScreenTurnsRemaining = 0,
    this.auroraVeilTurnsRemaining = 0,
  });
}

/// Move properties for special mechanics and damage calculations
class MoveProperties {
  final bool isZMove;
  final bool isDynamaxMove;
  final bool isProtected;
  final bool guaranteedCrit;
  final int critStage; // 0-3, higher = better crit chance
  final bool isParentalBondSecondHit;
  final bool targetsMinimizedOpponent;
  final bool targetInSemiInvulnerable; // Dig, Dive, Fly, etc.
  final String? semiInvulnerableType; // 'dig', 'dive', 'fly', etc.

  const MoveProperties({
    this.isZMove = false,
    this.isDynamaxMove = false,
    this.isProtected = false,
    this.guaranteedCrit = false,
    this.critStage = 0,
    this.isParentalBondSecondHit = false,
    this.targetsMinimizedOpponent = false,
    this.targetInSemiInvulnerable = false,
    this.semiInvulnerableType,
  });
}

/// Result of a damage calculation including range and hit chance
class DamageResult {
  final int minDamage;
  final int maxDamage;
  final double hitChance; // 0.0 to 1.0
  final bool isCriticalChance;
  final String?
      effectivenessString; // "super-effective", "not very effective", etc
  final bool isTypeImmune;
  final bool isDamageBlocked;
  final bool isDamagePartiallyBlocked;
  final List<int>? discreteDamageRolls; // All 16 possible damage values

  DamageResult({
    required this.minDamage,
    required this.maxDamage,
    required this.hitChance,
    required this.isCriticalChance,
    this.effectivenessString,
    required this.isTypeImmune,
    required this.isDamageBlocked,
    required this.isDamagePartiallyBlocked,
    this.discreteDamageRolls,
  });

  /// Calculate median of all discrete damage rolls for accurate average
  int get averageDamage {
    if (discreteDamageRolls == null || discreteDamageRolls!.isEmpty) {
      // Fallback to simple average if rolls not available
      return ((minDamage + maxDamage) / 2).toInt();
    }

    // For 16 values, use the lower of the two middle values
    final sorted = discreteDamageRolls!.toList()..sort();
    if (sorted.length.isEven) {
      final mid = sorted.length ~/ 2;
      return sorted[mid - 1]; // Lower of the two middle values
    } else {
      return sorted[sorted.length ~/ 2];
    }
  }

  double get damagePercentage => (averageDamage / maxDamage).clamp(0.0, 1.0);
}

/// Calculates damage for moves considering all modifiers and stat stages
class DamageCalculator {
  final TypeChartService _typeChart = TypeChartService();

  /// Ensure type chart is loaded before using DamageCalculator
  static Future<DamageCalculator> create() async {
    final calculator = DamageCalculator();
    await calculator._typeChart.loadTypeChart();
    return calculator;
  }

  /// Load the type chart data (must be called before calculateDamage)
  Future<void> loadTypeChart() async {
    await _typeChart.loadTypeChart();
  }

  /// Calculate damage for a move against a target
  DamageResult calculateDamage({
    required BattlePokemon attacker,
    required BattlePokemon defender,
    required Move move,
    required List<String> attackerTypes,
    required List<String> defenderTypes,
    List<String>? originalTypes,
    bool isTerastallized = false,
    bool targetIsGrounded = false,
    bool targetHasIronBall = false,
    bool targetUnderThousandArrows = false,
    bool targetHasRingTarget = false,
    bool targetUnderForesight = false,
    bool targetUnderOdorSleuth = false,
    bool targetUnderMiracleEye = false,
    bool strongWindsActive = false,
    bool targetUnderTarShot = false,
    bool glaiveRushActive = false,
    String? weather,
    int targetCount = 1,
    FieldState? fieldState,
    MoveProperties? moveProperties,
  }) {
    final field = fieldState ?? const FieldState();
    final props = moveProperties ?? const MoveProperties();
    // Status moves do no damage
    if (move.category == 'Status') {
      return DamageResult(
        minDamage: 0,
        maxDamage: 0,
        hitChance: 1.0,
        isCriticalChance: false,
        isTypeImmune: false,
        isDamageBlocked: false,
        isDamagePartiallyBlocked: false
      );
    }
    // Max Guard blocks everything
    if (defender.queuedAction is AttackAction && (defender.queuedAction as AttackAction).moveName == "Max Guard") {
      return DamageResult(
        minDamage: 0,
        maxDamage: 0,
        hitChance: 1.0,
        isCriticalChance: false,
        isTypeImmune: false,
        isDamageBlocked: true,
        isDamagePartiallyBlocked: false
      );
    }
    // If protected & move isn't a ZMove or Dynamax Move, do no damage
    if (props.isProtected && !props.isZMove && !props.isDynamaxMove) {
      return DamageResult(
        minDamage: 0,
        maxDamage: 0,
        hitChance: 1.0,
        isCriticalChance: false,
        isTypeImmune: false,
        isDamageBlocked: true,
        isDamagePartiallyBlocked: false
      );
    }

    final effectiveness = _calculateTypeEffectiveness(
      move: move,
      defenderTypes: defenderTypes,
      attackerAbility: attacker.ability,
      targetHasIronBall: targetHasIronBall,
      targetUnderThousandArrows: targetUnderThousandArrows,
      targetIsGrounded: targetIsGrounded,
      targetHasRingTarget: targetHasRingTarget,
      targetUnderForesight: targetUnderForesight,
      targetUnderOdorSleuth: targetUnderOdorSleuth,
      targetUnderMiracleEye: targetUnderMiracleEye,
      strongWindsActive: strongWindsActive,
      targetUnderTarShot: targetUnderTarShot,
    );
    if (effectiveness == 0.0) {
      return DamageResult(
        minDamage: 0,
        maxDamage: 0,
        hitChance: 1.0,
        isCriticalChance: false,
        effectivenessString: 'immune',
        isTypeImmune: true,
        isDamageBlocked: false,
        isDamagePartiallyBlocked: false
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
        isDamageBlocked: false,
        isDamagePartiallyBlocked: false
      );
    }

    // Apply attacker ability modifiers to base power (before stat calculation)
    baseDamage = _applyAbilityBasePowerModifier(attacker, move, baseDamage);

    // Determine attack and defense stats
    final useSpecial = move.category == 'Special';
    int atkStat = useSpecial
        ? attacker.stats?.spAtk ?? 100
        : attacker.stats?.attack ?? 100;
    final defStat = useSpecial
        ? defender.stats?.spDef ?? 100
        : defender.stats?.defense ?? 100;

    // Apply attacker ability modifiers to attack stat (before stat stages)
    atkStat = _applyAbilityAttackStatModifier(attacker, move, atkStat);

    // Apply stat stages
    final atkStage = attacker.statStages[useSpecial ? 'spa' : 'atk'] ?? 0;
    final defStage = defender.statStages[useSpecial ? 'spd' : 'def'] ?? 0;

    final effectiveAtk = StatStageCalculator.applyStatStage(
      baseStat: atkStat,
      stage: atkStage,
    );
    final effectiveDef = StatStageCalculator.applyStatStage(
      baseStat: defStat,
      stage: defStage,
    );

    // Calculate raw damage using Gen V+ formula:
    // (((2 * Level / 5 + 2) * Power * Attack / Defense) / 50 + 2)
    double levelPortion = ((2 * attacker.level) / 5.0) + 2;
    double attackPortion = levelPortion * baseDamage * effectiveAtk;
    double defensePortion = attackPortion / effectiveDef;
    double damageCalc = (defensePortion / 50.0) + 2;

    // Floor base damage before applying roll
    damageCalc = damageCalc.floor().toDouble();

    // Apply Targets modifier (0.75 if multiple targets)
    if (targetCount > 1) {
      damageCalc = _roundHalfDown(damageCalc * 0.75);
    }

    // Apply Parental Bond second hit modifier (0.25)
    if (props.isParentalBondSecondHit) {
      damageCalc = _roundHalfDown(damageCalc * 0.25);
    }

    // Apply weather modifiers
    final weatherMod = _getWeatherDamageModifier(
      move: move,
      weather: weather,
      attackerTypes: attackerTypes,
      defenderTypes: defenderTypes,
    );
    if (weatherMod != 1.0) {
      damageCalc = _roundHalfDown(damageCalc * weatherMod);
    }

    // Apply Glaive Rush modifier (2.0 if active)
    if (glaiveRushActive) {
      damageCalc = _roundHalfDown(damageCalc * 2.0);
    }

    // Apply Critical Hit modifier (1.5 unless prevented)
    final criticalMod = _getCriticalMultiplier(
      isCriticalHit:
          props.guaranteedCrit || _shouldCriticalHit(props.critStage),
      defenderAbility: defender.ability,
      fieldState: field,
    );
    if (criticalMod > 1.0) {
      damageCalc = _roundHalfDown(damageCalc * criticalMod);
    }

    // Apply random damage roll (85-100%)
    double minDamageDouble = damageCalc * minDamageRoll / maxDamageRoll;
    double maxDamageDouble = damageCalc;

    // Apply STAB (Same Type Attack Bonus)
    final stab = _calculateStabMultiplier(
      moveType: move.type,
      originalTypes: originalTypes ?? attackerTypes,
      teraType: attacker.teraType,
      isTerastallized: isTerastallized,
      ability: attacker.ability,
      isPledgeMove: _isPledgeMove(move),
    );
    minDamageDouble = minDamageDouble * stab;
    maxDamageDouble = maxDamageDouble * stab;

    // Apply type effectiveness
    minDamageDouble = minDamageDouble * effectiveness;
    maxDamageDouble = maxDamageDouble * effectiveness;

    // Apply Burn penalty (0.5 to physical moves)
    final burnMod = _getBurnModifier(attacker, move);
    minDamageDouble = minDamageDouble * burnMod;
    maxDamageDouble = maxDamageDouble * burnMod;

    // Apply "other" modifiers (complex stacking with 4096 precision)
    final otherMod = _getOtherModifier(
      attacker: attacker,
      defender: defender,
      move: move,
      attackerTypes: attackerTypes,
      defenderTypes: defenderTypes,
      effectiveness: effectiveness,
      isCriticalHit: criticalMod > 1.0,
      fieldState: field,
      moveProperties: props,
    );
    minDamageDouble = minDamageDouble * otherMod;
    maxDamageDouble = maxDamageDouble * otherMod;

    // Apply Z-Move protection modifier (0.25 if protected)
    if ((props.isZMove || props.isDynamaxMove) && props.isProtected) {
      minDamageDouble = minDamageDouble * 0.25;
      maxDamageDouble = maxDamageDouble * 0.25;
    }

    // Convert to int with proper rounding and clamp to valid range
    int minDamage = minDamageDouble.floor().clamp(1, 999999);
    int maxDamage = maxDamageDouble.floor().clamp(1, 999999);

    // Calculate discrete damage rolls for all possible random values (85-100)
    // Start from the base damageCalc value (before random roll) and apply all modifiers
    final discreteDamageRolls = <int>[];
    for (int roll = minDamageRoll; roll <= maxDamageRoll; roll++) {
      // Apply random roll to base damage
      double discreteDamage = damageCalc * roll / maxDamageRoll;
      // Apply STAB
      discreteDamage = discreteDamage * stab;
      // Apply type effectiveness
      discreteDamage = discreteDamage * effectiveness;
      // Apply burn modifier
      discreteDamage = discreteDamage * burnMod;
      // Apply other modifiers
      discreteDamage = discreteDamage * otherMod;
      // Apply Z-Move protection if applicable
      if ((props.isZMove || props.isDynamaxMove) && props.isProtected) {
        discreteDamage = discreteDamage * 0.25;
      }
      // Floor and clamp to valid range
      discreteDamageRolls.add(discreteDamage.floor().clamp(1, 999999));
    }

    // Hit accuracy
    double hitChance = _calculateHitChance(
      move.accuracy ?? 100,
      attacker.statStages['acc'] ?? 0,
      defender.statStages['eva'] ?? 0,
    );

    // Determine effectiveness string
    final effectivenessString =
        _typeChart.getEffectivenessString(effectiveness);

    // Calculate critical hit chance
    bool isCriticalChance = _calculateCriticalChance(props.critStage) > 0.0;

    return DamageResult(
      minDamage: minDamage,
      maxDamage: maxDamage,
      hitChance: hitChance,
      isCriticalChance: isCriticalChance,
      effectivenessString: effectivenessString,
      isTypeImmune: false,
      discreteDamageRolls: discreteDamageRolls,
      isDamageBlocked: false,
      isDamagePartiallyBlocked: (props.isZMove || props.isDynamaxMove) && props.isProtected
    );
  }

  /// Calculate hit accuracy considering move accuracy and stat stages
  double _calculateHitChance(
    int moveAccuracy,
    int accuracyStage,
    int evasionStage,
  ) {
    double baseAccuracy = moveAccuracy / 100.0;

    // Apply accuracy/evasion stages using StatStageCalculator
    final hitModifier = StatStageCalculator.calculateHitChanceMultiplier(
      accuracyStage: accuracyStage,
      evasionStage: evasionStage,
    );

    double finalAccuracy = baseAccuracy * hitModifier;
    return finalAccuracy.clamp(minAccuracy, maxAccuracy);
  }

  double _calculateStabMultiplier({
    required String moveType,
    required List<String> originalTypes,
    required String teraType,
    required bool isTerastallized,
    required String ability,
    required bool isPledgeMove,
  }) {
    final normalizedMoveType = moveType.trim();
    if (_isTypelessType(normalizedMoveType)) {
      return 1.0;
    }

    final filteredOriginalTypes =
        originalTypes.where((t) => !_isTypelessType(t)).toList();
    if (filteredOriginalTypes.isEmpty) {
      return 1.0;
    }

    final normalizedTeraType = teraType.trim();
    final hasAdaptability = ability.toLowerCase() == 'adaptability';
    final matchesOriginal = filteredOriginalTypes.contains(normalizedMoveType);
    final matchesTera = isTerastallized &&
        normalizedTeraType.isNotEmpty &&
        normalizedTeraType == normalizedMoveType;
    final teraMatchesOriginal =
        matchesTera && filteredOriginalTypes.contains(normalizedTeraType);

    if (!matchesOriginal && !matchesTera) {
      return 1.0;
    }

    // Pledge moves always use standard STAB (no Tera bonus)
    if (isPledgeMove) {
      return hasAdaptability ? 2.0 : stabMultiplier;
    }

    if (!isTerastallized) {
      return hasAdaptability ? 2.0 : stabMultiplier;
    }

    if (teraMatchesOriginal) {
      return hasAdaptability ? 2.25 : 2.0;
    }

    if (matchesTera) {
      return hasAdaptability ? 2.0 : stabMultiplier;
    }

    // Only original types match (not Tera): Adaptability does not increase
    return stabMultiplier;
  }

  double _calculateTypeEffectiveness({
    required Move move,
    required List<String> defenderTypes,
    required String attackerAbility,
    required bool targetHasIronBall,
    required bool targetUnderThousandArrows,
    required bool targetIsGrounded,
    required bool targetHasRingTarget,
    required bool targetUnderForesight,
    required bool targetUnderOdorSleuth,
    required bool targetUnderMiracleEye,
    required bool strongWindsActive,
    required bool targetUnderTarShot,
  }) {
    final normalizedMoveType = move.type.trim();
    final normalizedDefenderTypes = defenderTypes
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.trim())
        .toList();

    final isTargetTypeless = normalizedDefenderTypes.isEmpty ||
        normalizedDefenderTypes.any(_isTypelessType);

    if (move.name.toLowerCase() == 'struggle' ||
        (move.name.toLowerCase() == 'revelation dance' &&
            _isTypelessType(normalizedMoveType)) ||
        isTargetTypeless ||
        _isTypelessType(normalizedMoveType)) {
      return 1.0;
    }

    final hasFlyingType = normalizedDefenderTypes.contains('Flying');
    final isUngroundedFlying = hasFlyingType && !targetIsGrounded;

    if (normalizedMoveType == 'Ground' &&
        hasFlyingType &&
        isUngroundedFlying &&
        (targetHasIronBall || targetUnderThousandArrows)) {
      return 1.0;
    }

    double baseMultiplier = _calculateTypeMultiplierForType(
      attackingType: normalizedMoveType,
      defenderTypes: normalizedDefenderTypes,
      attackerAbility: attackerAbility,
      targetHasIronBall: targetHasIronBall,
      targetUnderThousandArrows: targetUnderThousandArrows,
      targetIsGrounded: targetIsGrounded,
      targetHasRingTarget: targetHasRingTarget,
      targetUnderForesight: targetUnderForesight,
      targetUnderOdorSleuth: targetUnderOdorSleuth,
      targetUnderMiracleEye: targetUnderMiracleEye,
      strongWindsActive: strongWindsActive,
      isFreezeDry: move.name.toLowerCase() == 'freeze-dry',
    );

    if (move.name.toLowerCase() == 'flying press') {
      final flyingMultiplier = _calculateTypeMultiplierForType(
        attackingType: 'Flying',
        defenderTypes: normalizedDefenderTypes,
        attackerAbility: attackerAbility,
        targetHasIronBall: targetHasIronBall,
        targetUnderThousandArrows: targetUnderThousandArrows,
        targetIsGrounded: targetIsGrounded,
        targetHasRingTarget: targetHasRingTarget,
        targetUnderForesight: targetUnderForesight,
        targetUnderOdorSleuth: targetUnderOdorSleuth,
        targetUnderMiracleEye: targetUnderMiracleEye,
        strongWindsActive: strongWindsActive,
        isFreezeDry: false,
      );
      baseMultiplier *= flyingMultiplier;
    }

    if (targetUnderTarShot && normalizedMoveType == 'Fire') {
      baseMultiplier *= 2.0;
    }

    return baseMultiplier;
  }

  double _calculateTypeMultiplierForType({
    required String attackingType,
    required List<String> defenderTypes,
    required String attackerAbility,
    required bool targetHasIronBall,
    required bool targetUnderThousandArrows,
    required bool targetIsGrounded,
    required bool targetHasRingTarget,
    required bool targetUnderForesight,
    required bool targetUnderOdorSleuth,
    required bool targetUnderMiracleEye,
    required bool strongWindsActive,
    required bool isFreezeDry,
  }) {
    double multiplier = 1.0;
    final ability = attackerAbility.toLowerCase();

    for (final defendingType in defenderTypes) {
      double matchup =
          _typeChart.getEffectiveness(attackingType, defendingType);

      if (attackingType == 'Ground' && defendingType == 'Flying') {
        if (targetIsGrounded &&
            !(targetHasIronBall || targetUnderThousandArrows)) {
          matchup = 1.0;
        }
      }

      if (strongWindsActive && defendingType == 'Flying' && matchup > 1.0) {
        matchup = 1.0;
      }

      if (isFreezeDry && attackingType == 'Ice' && defendingType == 'Water') {
        matchup = 2.0;
      }

      if (matchup == 0.0) {
        if (targetHasRingTarget) {
          matchup = 1.0;
        } else if ((ability == 'scrappy') &&
            defendingType == 'Ghost' &&
            (attackingType == 'Normal' || attackingType == 'Fighting')) {
          matchup = 1.0;
        } else if ((targetUnderForesight || targetUnderOdorSleuth) &&
            defendingType == 'Ghost' &&
            (attackingType == 'Normal' || attackingType == 'Fighting')) {
          matchup = 1.0;
        } else if (targetUnderMiracleEye &&
            defendingType == 'Dark' &&
            attackingType == 'Psychic') {
          matchup = 1.0;
        }
      }

      multiplier *= matchup;
    }

    return multiplier;
  }

  bool _isTypelessType(String type) {
    final normalized = type.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == '???' ||
        normalized == 'typeless' ||
        normalized == 'none' ||
        normalized == 'unknown';
  }

  bool _isPledgeMove(Move move) {
    return move.name.toLowerCase().contains('pledge');
  }

  /// Get damage modifier from weather
  double _getWeatherDamageModifier({
    required Move move,
    String? weather,
    required List<String> attackerTypes,
    required List<String> defenderTypes,
  }) {
    if (weather == null || weather.isEmpty) return 1.0;

    final moveType = move.type.trim();
    final normalizedWeather = weather.toLowerCase().trim();
    final isDefenderRockType = defenderTypes.contains('Rock');
    final isDefenderIceType = defenderTypes.contains('Ice');

    switch (normalizedWeather) {
      case 'sun':
        // Fire-type moves boosted by 50%
        if (moveType == 'Fire') return 1.5;
        // Water-type moves reduced by 50%
        if (moveType == 'Water') return 0.5;
        break;

      case 'harsh_sunlight':
        // Harsh Sunlight has all effects of sun plus:
        // Water-type moves fail (not handled here, should be checked before damage calculation)
        // Fire-type moves boosted by 50%
        if (moveType == 'Fire') return 1.5;
        // Water-type moves reduced by 50%
        if (moveType == 'Water') return 0.5;
        break;

      case 'rain':
        // Water-type moves boosted by 50%
        if (moveType == 'Water') return 1.5;
        // Fire-type moves reduced by 50%
        if (moveType == 'Fire') return 0.5;
        break;

      case 'heavy_rain':
        // Heavy Rain has all effects of rain plus:
        // Fire-type moves fail (not handled here, should be checked before damage calculation)
        // Water-type moves boosted by 50%
        if (moveType == 'Water') return 1.5;
        // Fire-type moves reduced by 50%
        if (moveType == 'Fire') return 0.5;
        break;

      case 'sandstorm':
        // Rock-type Pokémon Special Defense boosted by 50% (not damage mult, affects defense stat)
        // Sand Force ability: Ground/Rock/Steel moves boosted by 30% (handled in ability modifier)
        // For now, we'll apply the Rock-type special defense boost as a 0.67 incoming damage modifier for special moves from non-Rock types
        if (isDefenderRockType && move.category == 'Special') {
          return 0.67; // Inverse of 1.5x (0.67 ≈ 1/1.5)
        }
        break;

      case 'hail':
      case 'snow':
        // Ice-type Pokémon Defense boosted by 50% (not damage mult, affects defense stat)
        // For now, we'll apply the Ice-type defense boost as a 0.67 incoming damage modifier for physical moves from non-Ice types
        if (isDefenderIceType && move.category == 'Physical') {
          return 0.67; // Inverse of 1.5x (0.67 ≈ 1/1.5)
        }
        break;

      case 'strong_winds':
        // Strong winds reduce super-effective damage to Flying-types to normal
        // This is handled in _calculateTypeEffectiveness, not here
        break;
    }

    return 1.0;
  }

  /// Round to nearest integer, rounding down at 0.5
  static double _roundHalfDown(double value) {
    return value.floor() + (value - value.floor() < 0.5 ? 0.0 : 1.0);
  }

  /// Calculate critical hit chance based on crit stage
  static double _calculateCriticalChance(int critStage) {
    // Critical hit rates: Stage 0 = 1/24, Stage 1 = 1/8, Stage 2 = 1/2, Stage 3+ = 1/1
    switch (critStage) {
      case 0:
        return 1 / 24; // ~4.17%
      case 1:
        return 1 / 8; // 12.5%
      case 2:
        return 1 / 2; // 50%
      case 3:
      default:
        return 1.0; // 100%
    }
  }

  /// Determine if move should crit (for simulation purposes)
  static bool _shouldCriticalHit(int critStage) {
    // For now, return false to represent base damage
    // In actual battle simulation, this would use RNG
    return false;
  }

  /// Get critical hit multiplier
  static double _getCriticalMultiplier({
    required bool isCriticalHit,
    required String defenderAbility,
    required FieldState fieldState,
  }) {
    if (!isCriticalHit) return 1.0;

    // Check if critical hits are prevented
    final ability = defenderAbility.toLowerCase().trim();
    if (ability == 'battle armor' || ability == 'shell armor') {
      return 1.0;
    }

    if (fieldState.luckyChantActive) {
      return 1.0;
    }

    return 1.5;
  }

  /// Get burn penalty modifier
  static double _getBurnModifier(BattlePokemon attacker, Move move) {
    // Burn reduces physical damage by 50% unless attacker has Guts or move is Facade
    if (attacker.status?.toLowerCase() != 'burn') return 1.0;
    if (move.category != 'Physical') return 1.0;
    if (move.name.toLowerCase() == 'facade') return 1.0;
    if (attacker.ability.toLowerCase() == 'guts') return 1.0;

    return 0.5;
  }

  /// Apply ability modifiers to base power (before stat calculation)
  static int _applyAbilityBasePowerModifier(
    BattlePokemon attacker,
    Move move,
    int basePower,
  ) {
    final ability = attacker.ability.toLowerCase().trim();
    if (ability.isEmpty) return basePower;

    final moveType = move.type.trim();
    final hpPercent = attacker.currentHp / attacker.maxHp;
    final lowHp = hpPercent <= 0.33;

    // Type-specific boosts when HP is low (1.5x)
    if (lowHp) {
      if (ability == 'blaze' && moveType == 'Fire') {
        return (basePower * 1.5).round();
      }
      if (ability == 'torrent' && moveType == 'Water') {
        return (basePower * 1.5).round();
      }
      if (ability == 'overgrow' && moveType == 'Grass') {
        return (basePower * 1.5).round();
      }
      if (ability == 'swarm' && moveType == 'Bug') {
        return (basePower * 1.5).round();
      }
    }

    // Technician (1.5x for moves ≤ 60 power)
    if (ability == 'technician' && basePower <= 60) {
      return (basePower * 1.5).round();
    }

    // Type converters (convert Normal-type to different type and boost by 1.2x)
    if (moveType == 'Normal') {
      if (ability == 'aerilate') return (basePower * 1.2).round();
      if (ability == 'galvanize') return (basePower * 1.2).round();
      if (ability == 'pixilate') return (basePower * 1.2).round();
      if (ability == 'refrigerate') return (basePower * 1.2).round();
      if (ability == 'normalize') return (basePower * 1.2).round();
    }

    // Iron Fist (1.2x for punch moves)
    if (ability == 'iron fist' && _isPunchingMove(move)) {
      return (basePower * 1.2).round();
    }

    // Tough Claws (1.3x for contact moves)
    if (ability == 'tough claws' && move.makesContact) {
      return (basePower * 1.3).round();
    }

    // Reckless (1.2x for recoil moves)
    if (ability == 'reckless' && _isRecoilMove(move)) {
      return (basePower * 1.2).round();
    }

    // Sheer Force (1.3x if move has secondary effect)
    if (ability == 'sheer force' && _hasSecondaryEffect(move)) {
      return (basePower * 1.3).round();
    }

    // Mega Launcher (1.5x for aura/pulse moves)
    if (ability == 'mega launcher' && _isAuraOrPulseMove(move)) {
      return (basePower * 1.5).round();
    }

    // Strong Jaw (1.5x for biting moves)
    if (ability == 'strong jaw' && _isBitingMove(move)) {
      return (basePower * 1.5).round();
    }

    // Sharpness (1.5x for slicing moves)
    if (ability == 'sharpness' && _isSlicingMove(move)) {
      return (basePower * 1.5).round();
    }

    // Punk Rock (1.5x for sound moves when attacking)
    if (ability == 'punk rock' && _isSoundMove(move)) {
      return (basePower * 1.5).round();
    }

    return basePower;
  }

  /// Apply ability modifiers to attack stat (before stat stages)
  static int _applyAbilityAttackStatModifier(
    BattlePokemon attacker,
    Move move,
    int attackStat,
  ) {
    final ability = attacker.ability.toLowerCase().trim();
    if (ability.isEmpty) return attackStat;

    final isPhysical = move.category == 'Physical';
    final isSpecial = move.category == 'Special';

    // Huge Power / Pure Power (2x physical attack)
    if ((ability == 'huge power' || ability == 'pure power') && isPhysical) {
      return (attackStat * 2).round();
    }

    // Gorilla Tactics (1.5x physical attack)
    if (ability == 'gorilla tactics' && isPhysical) {
      return (attackStat * 1.5).round();
    }

    // Hustle (1.5x physical attack, but lowers accuracy)
    if (ability == 'hustle' && isPhysical) {
      return (attackStat * 1.5).round();
    }

    // Solar Power (1.5x special attack in harsh sunlight)
    // TODO: Check weather condition
    if (ability == 'solar power' && isSpecial) {
      // return (attackStat * 1.5).round();
    }

    // Slow Start (0.5x attack for first 5 turns)
    // TODO: Check turn count
    if (ability == 'slow start' && isPhysical) {
      // return (attackStat * 0.5).round();
    }

    // Defeatist (0.5x attack/special attack when HP < 50%)
    final hpPercent = attacker.currentHp / attacker.maxHp;
    if (ability == 'defeatist' && hpPercent < 0.5) {
      return (attackStat * 0.5).round();
    }

    return attackStat;
  }

  /// Get "other" modifier using 4096-precision stacking
  /// This includes all special ability, item, and move interactions per the official formula
  static double _getOtherModifier({
    required BattlePokemon attacker,
    required BattlePokemon defender,
    required Move move,
    required List<String> attackerTypes,
    required List<String> defenderTypes,
    required double effectiveness,
    required bool isCriticalHit,
    required FieldState fieldState,
    required MoveProperties moveProperties,
  }) {
    int modifier = 4096; // Base precision

    // Apply in order per official formula documentation:

    // 1. Behemoth Blade/Bash/Dynamax Cannon vs Dynamaxed (2.0x)
    if (moveProperties.isDynamaxMove &&
        _isDynamaxCannonLike(move) &&
        _isTargetDynamaxed(defender)) {
      modifier = (modifier * 2).round();
    }

    // 2. Moves vs Minimize (2.0x)
    if (moveProperties.targetsMinimizedOpponent && _isMinimizePunisher(move)) {
      modifier = (modifier * 2).round();
    }

    // 3. Earthquake/Magnitude vs Dig (2.0x)
    if (moveProperties.targetInSemiInvulnerable &&
        moveProperties.semiInvulnerableType == 'dig' &&
        _hitsDigTarget(move)) {
      modifier = (modifier * 2).round();
    }

    // 4. Surf/Whirlpool vs Dive (2.0x)
    if (moveProperties.targetInSemiInvulnerable &&
        moveProperties.semiInvulnerableType == 'dive' &&
        _hitsDiveTarget(move)) {
      modifier = (modifier * 2).round();
    }

    // 5. Reflect/Light Screen/Aurora Veil (0.5x)
    if (!isCriticalHit && attacker.ability.toLowerCase() != 'infiltrator') {
      if (fieldState.reflectActive && move.category == 'Physical') {
        modifier = (modifier * 0.5).round();
      } else if (fieldState.lightScreenActive && move.category == 'Special') {
        modifier = (modifier * 0.5).round();
      } else if (fieldState.auroraVeilActive) {
        modifier = (modifier * 0.5).round();
      }
    }

    // 6. Collision Course / Electro Drift (1.3333x if super effective)
    if (_isCollisionCourseOrElectroDrift(move) && effectiveness > 1.0) {
      modifier = (modifier * 5461 / 4096).round();
    }

    // 7. Multiscale/Shadow Shield at full HP (0.5x)
    final defAbility = defender.ability.toLowerCase().trim();
    if ((defAbility == 'multiscale' || defAbility == 'shadow shield') &&
        defender.currentHp >= defender.maxHp) {
      modifier = (modifier * 0.5).round();
    }

    // 8. Fluffy contact (0.5x)
    if (defAbility == 'fluffy' && move.makesContact) {
      modifier = (modifier * 0.5).round();
    }

    // 9. Punk Rock sound (0.5x)
    if (defAbility == 'punk rock' && _isSoundMove(move)) {
      modifier = (modifier * 0.5).round();
    }

    // 10. Ice Scales special (0.5x)
    if (defAbility == 'ice scales' && move.category == 'Special') {
      modifier = (modifier * 0.5).round();
    }

    // Additional defender abilities (type-specific reductions)
    // Thick Fat (0.5x Fire and Ice moves)
    if (defAbility == 'thick fat' &&
        (move.type.trim() == 'Fire' || move.type.trim() == 'Ice')) {
      modifier = (modifier * 0.5).round();
    }

    // Heatproof (0.5x Fire moves)
    if (defAbility == 'heatproof' && move.type.trim() == 'Fire') {
      modifier = (modifier * 0.5).round();
    }

    // Water Bubble (0.5x Fire moves)
    if (defAbility == 'water bubble' && move.type.trim() == 'Fire') {
      modifier = (modifier * 0.5).round();
    }

    // Purifying Salt (0.5x Ghost moves)
    if (defAbility == 'purifying salt' && move.type.trim() == 'Ghost') {
      modifier = (modifier * 0.5).round();
    }

    // Fur Coat (0.5x Physical moves)
    if (defAbility == 'fur coat' && move.category == 'Physical') {
      modifier = (modifier * 0.5).round();
    }

    // Dry Skin (1.25x Fire, 0.0x Water - water heals)
    if (defAbility == 'dry skin') {
      if (move.type.trim() == 'Fire') {
        modifier = (modifier * 1.25).round();
      }
      // Note: Water healing is handled elsewhere, not as damage modifier
    }

    // 11. Friend Guard (0.75x)
    // TODO: Check ally abilities (requires battle state tracking)

    // 12. Filter/Prism Armor/Solid Rock (0.75x if super effective)
    if ((defAbility == 'filter' ||
            defAbility == 'prism armor' ||
            defAbility == 'solid rock') &&
        effectiveness > 1.0) {
      modifier = (modifier * 0.75).round();
    }

    // 13. Neuroforce (1.25x if super effective)
    final atkAbility = attacker.ability.toLowerCase().trim();
    if (atkAbility == 'neuroforce' && effectiveness > 1.0) {
      modifier = (modifier * 1.25).round();
    }

    // 14. Sniper (1.5x on crit)
    if (atkAbility == 'sniper' && isCriticalHit) {
      modifier = (modifier * 1.5).round();
    }

    // 15. Tinted Lens (2.0x if not very effective)
    if (atkAbility == 'tinted lens' && effectiveness < 1.0) {
      modifier = (modifier * 2).round();
    }

    // 16. Fluffy Fire (2.0x)
    if (defAbility == 'fluffy' && move.type.trim() == 'Fire') {
      modifier = (modifier * 2).round();
    }

    // 17. Type-resist Berries (0.5x)
    if (_hasTypeResistBerry(defender, move.type) && effectiveness > 1.0) {
      modifier = (modifier * 0.5).round();
    }

    // 18. Expert Belt (1.2x if super effective)
    if (attacker.item?.toLowerCase() == 'expert belt' && effectiveness > 1.0) {
      modifier = (modifier * 4915 / 4096).round();
    }

    // 19. Life Orb (1.3x)
    if (attacker.item?.toLowerCase() == 'life orb') {
      modifier = (modifier * 5324 / 4096).round();
    }

    // 20. Metronome item (varies based on consecutive uses)
    // TODO: Requires turn tracking

    return modifier / 4096;
  }

  // Helper methods for "other" modifier checks
  static bool _isDynamaxCannonLike(Move move) {
    final name = move.name.toLowerCase();
    return name == 'behemoth blade' ||
        name == 'behemoth bash' ||
        name == 'dynamax cannon';
  }

  static bool _isTargetDynamaxed(BattlePokemon defender) {
    // TODO: Add Dynamax tracking to BattlePokemon
    return false;
  }

  static bool _isMinimizePunisher(Move move) {
    final name = move.name.toLowerCase();
    return [
      'body slam',
      'stomp',
      'dragon rush',
      'heat crash',
      'heavy slam',
      'flying press',
      'supercell slam'
    ].contains(name);
  }

  static bool _hitsDigTarget(Move move) {
    final name = move.name.toLowerCase();
    return name == 'earthquake' || name == 'magnitude';
  }

  static bool _hitsDiveTarget(Move move) {
    final name = move.name.toLowerCase();
    return name == 'surf' || name == 'whirlpool';
  }

  static bool _isCollisionCourseOrElectroDrift(Move move) {
    final name = move.name.toLowerCase();
    return name == 'collision course' || name == 'electro drift';
  }

  static bool _hasTypeResistBerry(BattlePokemon defender, String moveType) {
    final item = defender.item?.toLowerCase();
    if (item == null) return false;

    final berryMap = {
      'chilan berry': 'Normal',
      'occa berry': 'Fire',
      'passho berry': 'Water',
      'wacan berry': 'Electric',
      'rindo berry': 'Grass',
      'yache berry': 'Ice',
      'chople berry': 'Fighting',
      'kebia berry': 'Poison',
      'shuca berry': 'Ground',
      'coba berry': 'Flying',
      'payapa berry': 'Psychic',
      'tanga berry': 'Bug',
      'charti berry': 'Rock',
      'kasib berry': 'Ghost',
      'haban berry': 'Dragon',
      'colbur berry': 'Dark',
      'babiri berry': 'Steel',
      'roseli berry': 'Fairy',
    };

    return berryMap[item]?.toLowerCase() == moveType.toLowerCase();
  }

  // Helper methods for move classification
  static bool _isPunchingMove(Move move) {
    final punchingMoves = [
      'bullet punch',
      'comet punch',
      'dizzy punch',
      'double iron bash',
      'drain punch',
      'dynamic punch',
      'fire punch',
      'focus punch',
      'hammer arm',
      'ice punch',
      'mach punch',
      'mega punch',
      'meteor mash',
      'plasma fists',
      'power-up punch',
      'shadow punch',
      'sky uppercut',
      'thunder punch',
    ];
    return punchingMoves.contains(move.name.toLowerCase());
  }

  static bool _isBitingMove(Move move) {
    final bitingMoves = [
      'bite',
      'crunch',
      'fire fang',
      'fishious rend',
      'hyper fang',
      'ice fang',
      'jaw lock',
      'poison fang',
      'psychic fangs',
      'thunder fang',
    ];
    return bitingMoves.contains(move.name.toLowerCase());
  }

  static bool _isSlicingMove(Move move) {
    final slicingMoves = [
      'air cutter',
      'air slash',
      'aqua cutter',
      'behemoth blade',
      'bitter blade',
      'ceaseless edge',
      'cross poison',
      'cut',
      'fury cutter',
      'kowtow cleave',
      'leaf blade',
      'night slash',
      'population bomb',
      'psycho cut',
      'razor leaf',
      'razor shell',
      'sacred sword',
      'slash',
      'solar blade',
      'stone axe',
      'x-scissor',
    ];
    return slicingMoves.contains(move.name.toLowerCase());
  }

  static bool _isSoundMove(Move move) {
    final soundMoves = [
      'boomburst',
      'bug buzz',
      'chatter',
      'clanging scales',
      'clangorous soul',
      'confide',
      'disarming voice',
      'echoed voice',
      'grass whistle',
      'growl',
      'heal bell',
      'hyper voice',
      'metal sound',
      'noble roar',
      'overdrive',
      'parting shot',
      'perish song',
      'relic song',
      'roar',
      'round',
      'screech',
      'sing',
      'snarl',
      'snore',
      'sparkling aria',
      'supersonic',
      'uproar',
    ];
    return soundMoves.contains(move.name.toLowerCase());
  }

  static bool _isRecoilMove(Move move) {
    final recoilMoves = [
      'brave bird',
      'double-edge',
      'flare blitz',
      'head charge',
      'head smash',
      'high jump kick',
      'jump kick',
      'submission',
      'take down',
      'volt tackle',
      'wild charge',
      'wood hammer',
    ];
    return recoilMoves.contains(move.name.toLowerCase());
  }

  static bool _isAuraOrPulseMove(Move move) {
    final auraPulseMoves = [
      'aura sphere',
      'dark pulse',
      'dragon pulse',
      'heal pulse',
      'origin pulse',
      'terrain pulse',
      'water pulse',
    ];
    return auraPulseMoves.contains(move.name.toLowerCase());
  }

  static bool _hasSecondaryEffect(Move move) {
    // Simplified check - in reality, would need to check move data
    // Moves with secondary effects like burn, paralyze, flinch, stat changes, etc.
    return move.effectChance != null && (move.effectChance ?? 0) > 0;
  }
}

// Type chart and stat multiplier logic moved to shared utilities:
// - TypeChartService (lib/domain/utils/type_chart.dart)
// - StatStageCalculator (lib/domain/utils/stat_stage_calculator.dart)
// - battle_constants.dart for all numeric values
