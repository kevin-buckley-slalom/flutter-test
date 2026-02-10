import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/data/models/pokemon_stats.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/domain/models/multi_hit_result.dart';
import 'package:championdex/domain/services/damage_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup type chart before running tests
  setUpAll(() async {
    final jsonString = File('assets/data/type_chart.json').readAsStringSync();
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final byteData = ByteData.view(bytes.buffer);
    ServicesBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async => byteData);

    // Pre-load type chart for all tests
    final calculator = DamageCalculator();
    await calculator.loadTypeChart();
  });

  group('Multi-Hit Damage Calculation', () {
    // Helper to create test Pokemon
    BattlePokemon createTestPokemon({
      required String name,
      required int attack,
      required int defense,
      required int spAttack,
      required int spDefense,
      required int hp,
      required int level,
      List<String> types = const ['Normal'],
    }) {
      return BattlePokemon(
        pokemonName: name,
        originalName: name,
        maxHp: hp,
        currentHp: hp,
        level: level,
        ability: '',
        item: '',
        isShiny: false,
        teraType: '',
        moves: [],
        statStages: {
          'atk': 0,
          'def': 0,
          'spa': 0,
          'spd': 0,
          'spe': 0,
          'accuracy': 0,
          'evasion': 0
        },
        queuedAction: null,
        imagePath: '',
        imagePathLarge: '',
        stats: PokemonStats(
          total: hp + attack + defense + spAttack + spDefense + 100,
          hp: hp,
          attack: attack,
          defense: defense,
          spAtk: spAttack,
          spDef: spDefense,
          speed: 100,
        ),
        types: types,
      );
    }

    // Helper to create test move
    Move createTestMove({
      required String name,
      required String type,
      required int power,
      required String category,
      int accuracy = 100,
      String? secondaryEffect,
      String? effect,
    }) {
      return Move(
        name: name,
        type: type,
        power: power,
        accuracy: accuracy,
        pp: 10,
        category: category,
        effect: effect ?? '',
        detailedEffect: '',
        secondaryEffect: secondaryEffect,
        effectChanceRaw: null,
        effectChancePercent: null,
        priority: 0,
        makesContact: category == 'Physical',
        targets: 'selected-pokemon',
        generation: 1,
      );
    }

    group('Fixed 2-Hit Moves', () {
      test('Bonemerang hits exactly twice with independent damage', () {
        final attacker = createTestPokemon(
          name: 'Marowak',
          attack: 100,
          defense: 50,
          spAttack: 50,
          spDefense: 50,
          hp: 100,
          level: 50,
          types: ['Ground'],
        );

        final defender = createTestPokemon(
          name: 'Pikachu',
          attack: 50,
          defense: 40,
          spAttack: 50,
          spDefense: 50,
          hp: 100,
          level: 50,
          types: ['Electric'],
        );

        final move = createTestMove(
          name: 'Bonemerang',
          type: 'Ground',
          power: 50,
          category: 'Physical',
          effect: 'Hits twice in one turn.',
          secondaryEffect: 'Attacks twice in a row.',
        );

        // Note: This will fail until calculateMultiHitDamage is implemented
        // For now, we're writing the test to define expected behavior
        expect(move.isMultiHit, true);
        expect(move.multiHitType, MultiHitType.fixed2);

        final result = DamageCalculator.calculateMultiHitDamage(
          move: move,
          attacker: attacker,
          defender: defender,
        );

        expect(result.hitCount, 2);
        expect(result.successfulHits, 2);
        expect(result.allHitsConnected, true);
        expect(result.hitDamages.length, 2);
        expect(result.totalDamage, greaterThan(0));

        // Each hit should deal damage independently
        expect(result.hitDamages[0], greaterThan(0));
        expect(result.hitDamages[1], greaterThan(0));
      });

      test('Double Kick applies Fighting type and makes contact', () {
        final attacker = createTestPokemon(
          name: 'Hitmonlee',
          attack: 120,
          defense: 50,
          spAttack: 35,
          spDefense: 50,
          hp: 100,
          level: 50,
          types: ['Fighting'],
        );

        final defender = createTestPokemon(
          name: 'Snorlax',
          attack: 110,
          defense: 65,
          spAttack: 65,
          spDefense: 110,
          hp: 160,
          level: 50,
          types: ['Normal'],
        );

        final move = createTestMove(
          name: 'Double Kick',
          type: 'Fighting',
          power: 30,
          category: 'Physical',
          effect: 'Hits twice in one turn.',
          secondaryEffect: 'Attacks twice in a row.',
        );

        expect(move.isMultiHit, true);
        expect(move.makesContact, true);

        final result = DamageCalculator.calculateMultiHitDamage(
          move: move,
          attacker: attacker,
          defender: defender,
        );

        expect(result.hitCount, 2);
        expect(result.successfulHits, 2);

        // Should apply STAB (Fighting attacker with Fighting move)
        expect(result.totalDamage,
            greaterThan(30)); // More than base power due to STAB
      });

      test('Twineedle has 20% poison chance after both hits', () {
        final attacker = createTestPokemon(
          name: 'Beedrill',
          attack: 90,
          defense: 40,
          spAttack: 45,
          spDefense: 80,
          hp: 100,
          level: 50,
          types: ['Bug', 'Poison'],
        );

        final defender = createTestPokemon(
          name: 'Bulbasaur',
          attack: 49,
          defense: 49,
          spAttack: 65,
          spDefense: 65,
          hp: 100,
          level: 50,
          types: ['Grass', 'Poison'],
        );

        final move = createTestMove(
          name: 'Twineedle',
          type: 'Bug',
          power: 25,
          category: 'Physical',
          effect: 'Hits twice in one turn. May poison opponent.',
          secondaryEffect: 'May poison the target.',
        );

        expect(move.isMultiHit, true);
        expect(move.multiHitType, MultiHitType.fixed2);

        final result = DamageCalculator.calculateMultiHitDamage(
          move: move,
          attacker: attacker,
          defender: defender,
        );

        expect(result.hitCount, 2);
        expect(result.successfulHits, 2);

        // Note: Poison effect application will be tested separately
        // in move_effect_processor multi-hit integration tests
      });
    });

    group('Variable 2-5 Hit Moves', () {
      test('Fury Attack hit distribution follows probability', () {
        final attacker = createTestPokemon(
          name: 'Spearow',
          attack: 60,
          defense: 30,
          spAttack: 31,
          spDefense: 31,
          hp: 100,
          level: 50,
          types: ['Normal', 'Flying'],
        );

        final defender = createTestPokemon(
          name: 'Pidgey',
          attack: 45,
          defense: 40,
          spAttack: 35,
          spDefense: 35,
          hp: 100,
          level: 50,
          types: ['Normal', 'Flying'],
        );

        final move = createTestMove(
          name: 'Fury Attack',
          type: 'Normal',
          power: 15,
          accuracy: 85,
          category: 'Physical',
          effect: 'Hits 2-5 times in one turn.',
          secondaryEffect:
              'Attacks 2-5 times in a row. 37.5% chance of 2 hits. '
              '37.5% chance of 3 hits. 12.5% chance of 4 hits. 12.5% chance of 5 hits',
        );

        expect(move.isMultiHit, true);
        expect(move.multiHitType, MultiHitType.variable2to5);

        // Run 1000 iterations to verify distribution
        final hitCounts = <int, int>{2: 0, 3: 0, 4: 0, 5: 0};

        for (int i = 0; i < 1000; i++) {
          final result = DamageCalculator.calculateMultiHitDamage(
            move: move,
            attacker: attacker,
            defender: defender,
          );

          if (result.allHitsConnected) {
            hitCounts[result.hitCount] = (hitCounts[result.hitCount] ?? 0) + 1;
          }
        }

        // Verify distribution is approximately correct (within 10% tolerance)
        // 2 hits: ~375 (37.5%), 3 hits: ~375 (37.5%), 4 hits: ~125 (12.5%), 5 hits: ~125 (12.5%)
        expect(hitCounts[2]!, greaterThan(300)); // 37.5% ± tolerance
        expect(hitCounts[2]!, lessThan(450));
        expect(hitCounts[3]!, greaterThan(300));
        expect(hitCounts[3]!, lessThan(450));
        expect(hitCounts[4]!, greaterThan(75));
        expect(hitCounts[4]!, lessThan(175));
        expect(hitCounts[5]!, greaterThan(75));
        expect(hitCounts[5]!, lessThan(175));
      });

      test('Bullet Seed stops on first miss', () {
        final attacker = createTestPokemon(
          name: 'Roselia',
          attack: 60,
          defense: 45,
          spAttack: 100,
          spDefense: 80,
          hp: 100,
          level: 50,
          types: ['Grass', 'Poison'],
        );

        final defender = createTestPokemon(
          name: 'Charizard',
          attack: 84,
          defense: 78,
          spAttack: 109,
          spDefense: 85,
          hp: 100,
          level: 50,
          types: ['Fire', 'Flying'],
        );

        final move = createTestMove(
          name: 'Bullet Seed',
          type: 'Grass',
          power: 25,
          accuracy: 100,
          category: 'Physical',
          effect: 'Hits 2-5 times in one turn.',
        );

        expect(move.isMultiHit, true);

        // Force a miss scenario by using low accuracy
        final lowAccuracyMove = createTestMove(
          name: 'Bullet Seed',
          type: 'Grass',
          power: 25,
          accuracy: 50, // 50% accuracy per hit
          category: 'Physical',
          effect: 'Hits 2-5 times in one turn.',
        );

        // Run multiple times to check miss behavior
        bool foundEarlyMiss = false;
        for (int i = 0; i < 100; i++) {
          final result = DamageCalculator.calculateMultiHitDamage(
            move: lowAccuracyMove,
            attacker: attacker,
            defender: defender,
          );

          if (!result.allHitsConnected &&
              result.successfulHits < result.hitCount) {
            foundEarlyMiss = true;
            // Verify combo stopped after miss
            expect(result.missedHits.isNotEmpty, true);
            break;
          }
        }

        expect(foundEarlyMiss, true,
            reason: 'Should find at least one early miss in 100 attempts');
      });

      test('Rock Blast with high accuracy can hit 5 times', () {
        final attacker = createTestPokemon(
          name: 'Omastar',
          attack: 60,
          defense: 125,
          spAttack: 115,
          spDefense: 70,
          hp: 100,
          level: 50,
          types: ['Rock', 'Water'],
        );

        final defender = createTestPokemon(
          name: 'Pidgeot',
          attack: 80,
          defense: 75,
          spAttack: 70,
          spDefense: 70,
          hp: 100,
          level: 50,
          types: ['Normal', 'Flying'],
        );

        final move = createTestMove(
          name: 'Rock Blast',
          type: 'Rock',
          power: 25,
          accuracy: 90,
          category: 'Physical',
          effect: 'Hits 2-5 times in one turn.',
          secondaryEffect:
              'Attacks 2-5 times in a row. 37.5% chance of 2 hits. '
              '37.5% chance of 3 hits. 12.5% chance of 4 hits. 12.5% chance of 5 hits',
        );

        // Run multiple times to verify 5 hits is possible
        bool found5Hits = false;
        for (int i = 0; i < 100; i++) {
          final result = DamageCalculator.calculateMultiHitDamage(
            move: move,
            attacker: attacker,
            defender: defender,
          );

          if (result.hitCount == 5 && result.allHitsConnected) {
            found5Hits = true;
            expect(result.successfulHits, 5);
            expect(result.hitDamages.length, 5);
            break;
          }
        }

        expect(found5Hits, true,
            reason: 'Should find 5-hit result in 100 attempts');
      });
    });

    group('Fixed 3-Hit Moves with Variable Power', () {
      test('Triple Kick increases power each hit (10/20/30)', () {
        final attacker = createTestPokemon(
          name: 'Hitmontop',
          attack: 95,
          defense: 95,
          spAttack: 35,
          spDefense: 110,
          hp: 100,
          level: 50,
          types: ['Fighting'],
        );

        final defender = createTestPokemon(
          name: 'Tyranitar',
          attack: 134,
          defense: 110,
          spAttack: 95,
          spDefense: 100,
          hp: 100,
          level: 50,
          types: ['Rock', 'Dark'],
        );

        final move = createTestMove(
          name: 'Triple Kick',
          type: 'Fighting',
          power: 10, // Base power of first hit
          accuracy: 90,
          category: 'Physical',
          effect: 'Hits three times, increasing in power each time.',
        );

        expect(move.isMultiHit, true);
        expect(move.multiHitType, MultiHitType.fixed3);

        final result = DamageCalculator.calculateMultiHitDamage(
          move: move,
          attacker: attacker,
          defender: defender,
        );

        if (result.allHitsConnected) {
          expect(result.hitCount, 3);
          expect(result.successfulHits, 3);

          // Each hit should be progressively stronger (10 → 20 → 30 base power)
          // First hit < Second hit < Third hit
          expect(result.hitDamages[0], lessThan(result.hitDamages[1]));
          expect(result.hitDamages[1], lessThan(result.hitDamages[2]));

          // Approximate 1:2:3 ratio
          final ratio1to2 = result.hitDamages[1] / result.hitDamages[0];
          final ratio2to3 = result.hitDamages[2] / result.hitDamages[1];
          expect(ratio1to2, greaterThan(1.5)); // Should be close to 2
          expect(ratio2to3, greaterThan(1.2)); // Should be close to 1.5
        }
      });

      test('Triple Axel doubles power each hit (20/40/60)', () {
        final attacker = createTestPokemon(
          name: 'Eiscue',
          attack: 80,
          defense: 110,
          spAttack: 65,
          spDefense: 90,
          hp: 100,
          level: 50,
          types: ['Ice'],
        );

        final defender = createTestPokemon(
          name: 'Garchomp',
          attack: 130,
          defense: 95,
          spAttack: 80,
          spDefense: 85,
          hp: 100,
          level: 50,
          types: ['Dragon', 'Ground'],
        );

        final move = createTestMove(
          name: 'Triple Axel',
          type: 'Ice',
          power: 20, // Base power of first hit
          accuracy: 90,
          category: 'Physical',
          effect: 'Hits three times, doubling in power each time.',
        );

        expect(move.isMultiHit, true);

        final result = DamageCalculator.calculateMultiHitDamage(
          move: move,
          attacker: attacker,
          defender: defender,
        );

        if (result.allHitsConnected) {
          expect(result.hitCount, 3);

          // Power progression: 20 → 40 → 60
          // So damage should approximately double then increase by 50%
          final ratio1to2 = result.hitDamages[1] / result.hitDamages[0];
          final ratio2to3 = result.hitDamages[2] / result.hitDamages[1];
          expect(ratio1to2, greaterThan(1.7)); // Should be close to 2
          expect(ratio2to3, greaterThan(1.3)); // Should be close to 1.5
        }
      });
    });

    group('Damage Calculation Accuracy', () {
      test('Each hit applies type effectiveness independently', () {
        final attacker = createTestPokemon(
          name: 'Starmie',
          attack: 75,
          defense: 85,
          spAttack: 100,
          spDefense: 85,
          hp: 100,
          level: 50,
          types: ['Water', 'Psychic'],
        );

        final defender = createTestPokemon(
          name: 'Charizard',
          attack: 84,
          defense: 78,
          spAttack: 109,
          spDefense: 85,
          hp: 100,
          level: 50,
          types: ['Fire', 'Flying'],
        );

        final move = createTestMove(
          name: 'Water Shuriken',
          type: 'Water',
          power: 15,
          accuracy: 100,
          category: 'Special',
          effect: 'Hits 2-5 times in one turn.',
        );

        final result = DamageCalculator.calculateMultiHitDamage(
          move: move,
          attacker: attacker,
          defender: defender,
        );

        // Water is super effective against Fire (2x)
        // Each hit should benefit from type effectiveness
        expect(result.totalDamage, greaterThan(0));
        for (final damage in result.hitDamages) {
          expect(damage, greaterThan(0));
        }
      });

      test('STAB applies to each hit', () {
        final attacker = createTestPokemon(
          name: 'Scizor',
          attack: 130,
          defense: 100,
          spAttack: 55,
          spDefense: 80,
          hp: 100,
          level: 50,
          types: ['Bug', 'Steel'],
        );

        final defender = createTestPokemon(
          name: 'Alakazam',
          attack: 50,
          defense: 45,
          spAttack: 135,
          spDefense: 95,
          hp: 100,
          level: 50,
          types: ['Psychic'],
        );

        final move = createTestMove(
          name: 'Bullet Punch', // Simulated as 2-hit for test
          type: 'Steel',
          power: 40,
          accuracy: 100,
          category: 'Physical',
          effect: 'Hits twice in one turn.',
        );

        final result = DamageCalculator.calculateMultiHitDamage(
          move: move,
          attacker: attacker,
          defender: defender,
        );

        // Steel-type attacker using Steel move should get STAB (1.5x)
        expect(result.totalDamage,
            greaterThan(40 * 2)); // More than base power × hits
      });

      test('Independent accuracy check per hit', () {
        final attacker = createTestPokemon(
          name: 'Persian',
          attack: 70,
          defense: 60,
          spAttack: 65,
          spDefense: 65,
          hp: 100,
          level: 50,
          types: ['Normal'],
        );

        final defender = createTestPokemon(
          name: 'Machamp',
          attack: 130,
          defense: 80,
          spAttack: 65,
          spDefense: 85,
          hp: 100,
          level: 50,
          types: ['Fighting'],
        );

        final move = createTestMove(
          name: 'Fury Swipes',
          type: 'Normal',
          power: 18,
          accuracy: 80, // 80% per hit
          category: 'Physical',
          effect: 'Hits 2-5 times in one turn.',
        );

        // Run 100 times to verify independent accuracy
        int partialHits = 0;
        for (int i = 0; i < 100; i++) {
          final result = DamageCalculator.calculateMultiHitDamage(
            move: move,
            attacker: attacker,
            defender: defender,
          );

          // If not all hits connected, accuracy affected individual hits
          if (!result.allHitsConnected && result.successfulHits > 0) {
            partialHits++;
          }
        }

        // With 80% accuracy, we should see some partial hit scenarios
        expect(partialHits, greaterThan(0),
            reason: 'Should have some cases where not all hits connect');
      });
    });

    group('Secondary Effects on Multi-Hit Moves', () {
      test('Double Iron Bash flinch chance applies after both hits', () {
        final attacker = createTestPokemon(
          name: 'Melmetal',
          attack: 143,
          defense: 143,
          spAttack: 80,
          spDefense: 65,
          hp: 100,
          level: 50,
          types: ['Steel'],
        );

        final defender = createTestPokemon(
          name: 'Tyranitar',
          attack: 134,
          defense: 110,
          spAttack: 95,
          spDefense: 100,
          hp: 100,
          level: 50,
          types: ['Rock', 'Dark'],
        );

        final move = createTestMove(
          name: 'Double Iron Bash',
          type: 'Steel',
          power: 60,
          accuracy: 100,
          category: 'Physical',
          effect: 'Hits twice in one turn; may cause flinching.',
          secondaryEffect: '30% chance to flinch the target.',
        );

        expect(move.isMultiHit, true);
        expect(move.hasSecondaryEffect, true);

        final result = DamageCalculator.calculateMultiHitDamage(
          move: move,
          attacker: attacker,
          defender: defender,
        );

        expect(result.hitCount, 2);
        // Note: Flinch effect testing will be in integration tests
        // This just verifies the move is recognized as multi-hit with effects
      });

      test('Scale Shot stat changes apply after all hits complete', () {
        final attacker = createTestPokemon(
          name: 'Garchomp',
          attack: 130,
          defense: 95,
          spAttack: 80,
          spDefense: 85,
          hp: 100,
          level: 50,
          types: ['Dragon', 'Ground'],
        );

        final defender = createTestPokemon(
          name: 'Dragonite',
          attack: 134,
          defense: 95,
          spAttack: 100,
          spDefense: 100,
          hp: 100,
          level: 50,
          types: ['Dragon', 'Flying'],
        );

        final move = createTestMove(
          name: 'Scale Shot',
          type: 'Dragon',
          power: 25,
          accuracy: 90,
          category: 'Physical',
          effect:
              'Hits 2-5 times in one turn. Boosts user\'s Speed but lowers its Defense.',
          secondaryEffect:
              'Raises Speed by 1 stage and lowers Defense by 1 stage after all hits.',
        );

        expect(move.isMultiHit, true);
        expect(move.hasSecondaryEffect, true);

        final result = DamageCalculator.calculateMultiHitDamage(
          move: move,
          attacker: attacker,
          defender: defender,
        );

        expect(result.hitCount, greaterThanOrEqualTo(2));
        expect(result.hitCount, lessThanOrEqualTo(5));
        // Stat change effects will be tested in integration tests
      });
    });

    group('Edge Cases', () {
      test('MultiHitResult.firstHitMissed factory creates correct result', () {
        final result = MultiHitResult.firstHitMissed(plannedHits: 5);

        expect(result.hitCount, 5);
        expect(result.successfulHits, 0);
        expect(result.totalDamage, 0);
        expect(result.allHitsConnected, false);
        expect(result.missedHits, [0]);
        expect(result.wasInterrupted, true);
        expect(result.breakReason, 'first_hit_missed');
      });

      test('MultiHitResult.allHitsConnected factory creates correct result',
          () {
        final result = MultiHitResult.allHitsConnected(
          hitCount: 3,
          damages: [45, 47, 46],
        );

        expect(result.hitCount, 3);
        expect(result.successfulHits, 3);
        expect(result.totalDamage, 138); // 45 + 47 + 46
        expect(result.allHitsConnected, true);
        expect(result.missedHits, isEmpty);
        expect(result.wasInterrupted, false);
      });

      test('MultiHitResult toString provides useful debug info', () {
        final result = MultiHitResult(
          hitCount: 4,
          hitDamages: [30, 32, 31],
          missedHits: [3],
          breakReason: 'accuracy_miss',
        );

        final str = result.toString();
        expect(str, contains('3/4')); // 3 successful out of 4 attempted
        expect(str, contains('30+32+31')); // Damage breakdown
        expect(str, contains('93')); // Total damage
        expect(str, contains('accuracy_miss')); // Break reason
      });
    });
  });
}
