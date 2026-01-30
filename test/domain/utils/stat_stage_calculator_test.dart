import 'package:flutter_test/flutter_test.dart';
import 'package:championdex/domain/utils/stat_stage_calculator.dart';

void main() {
  group('StatStageCalculator - Basic Multipliers', () {
    test('Stage 0 returns 1.0× (no modifier)', () {
      expect(StatStageCalculator.getMultiplier(0), equals(1.0));
    });

    test('Stage +1 returns 1.5× multiplier', () {
      expect(StatStageCalculator.getMultiplier(1), equals(1.5));
    });

    test('Stage +2 returns 2.0× multiplier', () {
      expect(StatStageCalculator.getMultiplier(2), equals(2.0));
    });

    test('Stage +3 returns 2.5× multiplier', () {
      expect(StatStageCalculator.getMultiplier(3), equals(2.5));
    });

    test('Stage +4 returns 3.0× multiplier', () {
      expect(StatStageCalculator.getMultiplier(4), equals(3.0));
    });

    test('Stage +5 returns 3.5× multiplier', () {
      expect(StatStageCalculator.getMultiplier(5), equals(3.5));
    });

    test('Stage +6 returns 4.0× multiplier (maximum)', () {
      expect(StatStageCalculator.getMultiplier(6), equals(4.0));
    });

    test('Stage -1 returns ~0.67× multiplier', () {
      expect(StatStageCalculator.getMultiplier(-1), closeTo(0.67, 0.01));
    });

    test('Stage -2 returns 0.5× multiplier', () {
      expect(StatStageCalculator.getMultiplier(-2), equals(0.5));
    });

    test('Stage -3 returns ~0.4× multiplier', () {
      expect(StatStageCalculator.getMultiplier(-3), closeTo(0.4, 0.01));
    });

    test('Stage -4 returns ~0.33× multiplier', () {
      expect(StatStageCalculator.getMultiplier(-4), closeTo(0.33, 0.01));
    });

    test('Stage -5 returns ~0.29× multiplier', () {
      expect(StatStageCalculator.getMultiplier(-5), closeTo(0.29, 0.01));
    });

    test('Stage -6 returns 0.25× multiplier (minimum)', () {
      expect(StatStageCalculator.getMultiplier(-6), equals(0.25));
    });
  });

  group('StatStageCalculator - Apply Stat Stage', () {
    test('Apply +1 stage to 100 base stat', () {
      final result = StatStageCalculator.applyStatStage(
        baseStat: 100,
        stage: 1,
      );
      expect(result, equals(150)); // 100 × 1.5
    });

    test('Apply +2 stage to 200 base stat', () {
      final result = StatStageCalculator.applyStatStage(
        baseStat: 200,
        stage: 2,
      );
      expect(result, equals(400)); // 200 × 2.0
    });

    test('Apply -1 stage to 300 base stat', () {
      final result = StatStageCalculator.applyStatStage(
        baseStat: 300,
        stage: -1,
      );
      expect(result, equals(200)); // 300 × 0.666... ≈ 200
    });

    test('Apply -2 stage to 150 base stat', () {
      final result = StatStageCalculator.applyStatStage(
        baseStat: 150,
        stage: -2,
      );
      expect(result, equals(75)); // 150 × 0.5
    });

    test('Apply +6 stage to 100 base stat', () {
      final result = StatStageCalculator.applyStatStage(
        baseStat: 100,
        stage: 6,
      );
      expect(result, equals(400)); // 100 × 4.0
    });

    test('Apply -6 stage to 400 base stat', () {
      final result = StatStageCalculator.applyStatStage(
        baseStat: 400,
        stage: -6,
      );
      expect(result, equals(100)); // 400 × 0.25
    });
  });

  group('StatStageCalculator - Add Stages', () {
    test('Add stages normally within bounds', () {
      expect(StatStageCalculator.addStages(0, 1), equals(1));
      expect(StatStageCalculator.addStages(1, 1), equals(2));
      expect(StatStageCalculator.addStages(2, 2), equals(4));
    });

    test('Adding stages caps at +6', () {
      expect(StatStageCalculator.addStages(4, 3), equals(6));
      expect(StatStageCalculator.addStages(5, 5), equals(6));
      expect(StatStageCalculator.addStages(6, 1), equals(6));
    });

    test('Subtracting stages caps at -6', () {
      expect(StatStageCalculator.addStages(-4, -3), equals(-6));
      expect(StatStageCalculator.addStages(-5, -5), equals(-6));
      expect(StatStageCalculator.addStages(-6, -1), equals(-6));
    });

    test('Adding positive and negative stages', () {
      expect(StatStageCalculator.addStages(2, -1), equals(1));
      expect(StatStageCalculator.addStages(-2, 3), equals(1));
      expect(StatStageCalculator.addStages(3, -3), equals(0));
    });
  });

  group('StatStageCalculator - Stage Descriptions', () {
    test('Stage 0 description', () {
      expect(
        StatStageCalculator.getStageDescription(0),
        equals('Normal (1.00×)'),
      );
    });

    test('Positive stage descriptions', () {
      expect(
        StatStageCalculator.getStageDescription(1),
        equals('+1 (1.50×)'),
      );
      expect(
        StatStageCalculator.getStageDescription(2),
        equals('+2 (2.00×)'),
      );
      expect(
        StatStageCalculator.getStageDescription(6),
        equals('+6 (4.00×) Maximum'),
      );
    });

    test('Negative stage descriptions', () {
      expect(
        StatStageCalculator.getStageDescription(-1),
        contains('-1'),
      );
      expect(
        StatStageCalculator.getStageDescription(-2),
        equals('-2 (0.50×)'),
      );
      expect(
        StatStageCalculator.getStageDescription(-6),
        equals('-6 (0.25×) Minimum'),
      );
    });
  });

  group('StatStageCalculator - Move Stage Changes', () {
    test('Apply Swords Dance (+2 Attack)', () {
      final currentStages = {'atk': 0, 'def': 0, 'spa': 0, 'spd': 0, 'spe': 0};
      final changes = {'atk': 2};

      final result = StatStageCalculator.applyMoveStageChanges(
        currentStages: currentStages,
        stageChanges: changes,
      );

      expect(result['atk'], equals(2));
      expect(result['def'], equals(0));
    });

    test('Apply Intimidate (-1 Attack to opponent)', () {
      final currentStages = {'atk': 0};
      final changes = {'atk': -1};

      final result = StatStageCalculator.applyMoveStageChanges(
        currentStages: currentStages,
        stageChanges: changes,
      );

      expect(result['atk'], equals(-1));
    });

    test('Apply Draco Meteor (-2 Sp. Atk self)', () {
      final currentStages = {'spa': 0};
      final changes = {'spa': -2};

      final result = StatStageCalculator.applyMoveStageChanges(
        currentStages: currentStages,
        stageChanges: changes,
      );

      expect(result['spa'], equals(-2));
    });

    test('Multiple stat changes (Dragon Dance: +1 Atk, +1 Spe)', () {
      final currentStages = {'atk': 0, 'spe': 0};
      final changes = {'atk': 1, 'spe': 1};

      final result = StatStageCalculator.applyMoveStageChanges(
        currentStages: currentStages,
        stageChanges: changes,
      );

      expect(result['atk'], equals(1));
      expect(result['spe'], equals(1));
    });

    test('Capping at maximum with Belly Drum (+6 Attack)', () {
      final currentStages = {'atk': 0};
      final changes = {'atk': 6};

      final result = StatStageCalculator.applyMoveStageChanges(
        currentStages: currentStages,
        stageChanges: changes,
      );

      expect(result['atk'], equals(6));
    });

    test('Capping works even when starting above 0', () {
      final currentStages = {'atk': 4};
      final changes = {'atk': 3}; // Would be 7, but caps at 6

      final result = StatStageCalculator.applyMoveStageChanges(
        currentStages: currentStages,
        stageChanges: changes,
      );

      expect(result['atk'], equals(6));
    });
  });

  group('StatStageCalculator - Stage Checks', () {
    test('isMaxStage returns true for +6', () {
      expect(StatStageCalculator.isMaxStage(6), isTrue);
      expect(StatStageCalculator.isMaxStage(7), isTrue); // Still max
    });

    test('isMaxStage returns false for below +6', () {
      expect(StatStageCalculator.isMaxStage(5), isFalse);
      expect(StatStageCalculator.isMaxStage(0), isFalse);
      expect(StatStageCalculator.isMaxStage(-6), isFalse);
    });

    test('isMinStage returns true for -6', () {
      expect(StatStageCalculator.isMinStage(-6), isTrue);
      expect(StatStageCalculator.isMinStage(-7), isTrue); // Still min
    });

    test('isMinStage returns false for above -6', () {
      expect(StatStageCalculator.isMinStage(-5), isFalse);
      expect(StatStageCalculator.isMinStage(0), isFalse);
      expect(StatStageCalculator.isMinStage(6), isFalse);
    });

    test('resetStage returns 0', () {
      expect(StatStageCalculator.resetStage(), equals(0));
    });
  });

  group('StatStageCalculator - Accuracy/Evasion', () {
    test('Accuracy stage 0 returns 1.0×', () {
      expect(StatStageCalculator.getAccuracyMultiplier(0), equals(1.0));
    });

    test('Accuracy stage +1 returns ~1.33×', () {
      expect(
        StatStageCalculator.getAccuracyMultiplier(1),
        closeTo(1.33, 0.01),
      );
    });

    test('Accuracy stage +2 returns ~1.67×', () {
      expect(
        StatStageCalculator.getAccuracyMultiplier(2),
        closeTo(1.67, 0.01),
      );
    });

    test('Accuracy stage +6 returns 3.0×', () {
      expect(StatStageCalculator.getAccuracyMultiplier(6), equals(3.0));
    });

    test('Accuracy stage -1 returns 0.75×', () {
      expect(StatStageCalculator.getAccuracyMultiplier(-1), equals(0.75));
    });

    test('Accuracy stage -2 returns 0.6×', () {
      expect(StatStageCalculator.getAccuracyMultiplier(-2), equals(0.6));
    });

    test('Accuracy stage -6 returns ~0.33×', () {
      expect(
        StatStageCalculator.getAccuracyMultiplier(-6),
        closeTo(0.33, 0.01),
      );
    });
  });

  group('StatStageCalculator - Hit Chance Calculation', () {
    test('Normal hit chance (0 accuracy, 0 evasion)', () {
      final multiplier = StatStageCalculator.calculateHitChanceMultiplier(
        accuracyStage: 0,
        evasionStage: 0,
      );
      expect(multiplier, equals(1.0));
    });

    test('Hit chance with +1 accuracy', () {
      final multiplier = StatStageCalculator.calculateHitChanceMultiplier(
        accuracyStage: 1,
        evasionStage: 0,
      );
      expect(multiplier, closeTo(1.33, 0.01));
    });

    test('Hit chance with +1 evasion on opponent', () {
      final multiplier = StatStageCalculator.calculateHitChanceMultiplier(
        accuracyStage: 0,
        evasionStage: 1,
      );
      expect(multiplier, equals(0.75));
    });

    test('Hit chance with +1 accuracy vs +1 evasion', () {
      final multiplier = StatStageCalculator.calculateHitChanceMultiplier(
        accuracyStage: 1,
        evasionStage: 1,
      );
      expect(multiplier, equals(1.0)); // They cancel out
    });

    test('Hit chance with -2 accuracy (Sand Attack)', () {
      final multiplier = StatStageCalculator.calculateHitChanceMultiplier(
        accuracyStage: -2,
        evasionStage: 0,
      );
      expect(multiplier, equals(0.6));
    });

    test('Hit chance with +6 evasion (maximum Double Team)', () {
      final multiplier = StatStageCalculator.calculateHitChanceMultiplier(
        accuracyStage: 0,
        evasionStage: 6,
      );
      expect(multiplier, closeTo(0.33, 0.01));
    });
  });

  group('StatStageCalculator - Common Battle Scenarios', () {
    test('Swords Dance doubles Attack (+2 stages)', () {
      final beforeAttack = 200;
      final afterAttack = StatStageCalculator.applyStatStage(
        baseStat: beforeAttack,
        stage: 2,
      );
      expect(afterAttack, equals(400));
    });

    test('Intimidate reduces opponent Attack by 33%', () {
      final beforeAttack = 300;
      final afterAttack = StatStageCalculator.applyStatStage(
        baseStat: beforeAttack,
        stage: -1,
      );
      expect(afterAttack, equals(200)); // ~0.67× = 33% reduction
    });

    test('Two Swords Dances quadruple Attack (+4 stages)', () {
      final beforeAttack = 100;
      final afterAttack = StatStageCalculator.applyStatStage(
        baseStat: beforeAttack,
        stage: 4,
      );
      expect(afterAttack, equals(300)); // 100 × 3.0
    });

    test('Sticky Web reduces Speed by 50% (-1 stage)', () {
      final beforeSpeed = 200;
      final afterSpeed = StatStageCalculator.applyStatStage(
        baseStat: beforeSpeed,
        stage: -1,
      );
      expect(afterSpeed, equals(133)); // ~0.67×
    });

    test('Paralysis is separate from stat stages', () {
      // Note: Paralysis is 0.5× speed, not a stat stage
      // This test verifies -2 stages also gives 0.5×
      final beforeSpeed = 200;
      final afterSpeed = StatStageCalculator.applyStatStage(
        baseStat: beforeSpeed,
        stage: -2,
      );
      expect(afterSpeed, equals(100)); // 0.5×
    });
  });

  group('StatStageCalculator - Edge Cases', () {
    test('Stages beyond +6 are clamped to +6', () {
      expect(StatStageCalculator.getMultiplier(10), equals(4.0));
      expect(StatStageCalculator.getMultiplier(100), equals(4.0));
    });

    test('Stages beyond -6 are clamped to -6', () {
      expect(StatStageCalculator.getMultiplier(-10), equals(0.25));
      expect(StatStageCalculator.getMultiplier(-100), equals(0.25));
    });

    test('Very low base stat still benefits from boosts', () {
      final result = StatStageCalculator.applyStatStage(
        baseStat: 10,
        stage: 6,
      );
      expect(result, equals(40)); // 10 × 4.0
    });

    test('Very high base stat still affected by reductions', () {
      final result = StatStageCalculator.applyStatStage(
        baseStat: 1000,
        stage: -6,
      );
      expect(result, equals(250)); // 1000 × 0.25
    });
  });
}
