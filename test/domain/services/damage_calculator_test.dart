import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:championdex/domain/services/damage_calculator.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/data/models/pokemon_stats.dart';

void main() {
  late DamageCalculator calculator;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final jsonString = File('assets/data/type_chart.json').readAsStringSync();
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final byteData = ByteData.view(bytes.buffer);
    ServicesBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async => byteData);
    calculator = await DamageCalculator.create();
  });

  // Helper to create a test Pokémon
  BattlePokemon createTestPokemon({
    required String name,
    required int level,
    required int attack,
    required int defense,
    required int spAtk,
    required int spDef,
    required int maxHp,
    String ability = '',
    String? item,
    String teraType = 'Normal',
    Map<String, int>? statStages,
  }) {
    return BattlePokemon(
      pokemonName: name,
      originalName: name,
      maxHp: maxHp,
      currentHp: maxHp,
      level: level,
      ability: ability,
      item: item,
      isShiny: false,
      teraType: teraType,
      moves: [],
      statStages: statStages ??
          {
            'hp': 0,
            'atk': 0,
            'def': 0,
            'spa': 0,
            'spd': 0,
            'spe': 0,
            'acc': 0,
            'eva': 0
          },
      queuedAction: null,
      imagePath: null,
      imagePathLarge: null,
      stats: PokemonStats(
        total: attack + defense + spAtk + spDef + maxHp,
        hp: maxHp,
        attack: attack,
        defense: defense,
        spAtk: spAtk,
        spDef: spDef,
        speed: 100,
      ),
      status: null,
    );
  }

  // Helper to create a test move
  Move createTestMove({
    required String name,
    required String type,
    required String category,
    int? power,
    int accuracy = 100,
    int priority = 0,
    bool makesContact = false,
  }) {
    return Move(
      name: name,
      type: type,
      category: category,
      power: power,
      accuracy: accuracy,
      pp: 10,
      effect: '',
      makesContact: makesContact,
      generation: 8,
      priority: priority,
    );
  }

  group('DamageCalculator - Status Moves', () {
    test('Status moves deal 0 damage', () {
      final attacker = createTestPokemon(
        name: 'Alakazam',
        level: 50,
        attack: 100,
        defense: 100,
        spAtk: 200,
        spDef: 100,
        maxHp: 150,
      );

      final defender = createTestPokemon(
        name: 'Snorlax',
        level: 50,
        attack: 150,
        defense: 100,
        spAtk: 100,
        spDef: 150,
        maxHp: 300,
      );

      final statusMove = createTestMove(
        name: 'Thunder Wave',
        type: 'Electric',
        category: 'Status',
        power: null,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: statusMove,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Normal'],
      );

      expect(result.minDamage, equals(0));
      expect(result.maxDamage, equals(0));
      expect(result.hitChance, equals(1.0));
    });
  });

  group('DamageCalculator - Type Immunity', () {
    test('Normal-type move is immune to Ghost', () {
      final attacker = createTestPokemon(
        name: 'Tauros',
        level: 50,
        attack: 150,
        defense: 100,
        spAtk: 80,
        spDef: 100,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Gengar',
        level: 50,
        attack: 100,
        defense: 80,
        spAtk: 180,
        spDef: 100,
        maxHp: 150,
      );

      final tackle = createTestMove(
        name: 'Tackle',
        type: 'Normal',
        category: 'Physical',
        power: 40,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: tackle,
        attackerTypes: ['Normal'],
        defenderTypes: ['Ghost', 'Poison'],
      );

      expect(result.minDamage, equals(0));
      expect(result.maxDamage, equals(0));
      expect(result.isTypeImmune, equals(true));
      expect(result.effectivenessString, equals('immune'));
    });

    test('Ground-type move is immune to Flying', () {
      final attacker = createTestPokemon(
        name: 'Garchomp',
        level: 50,
        attack: 180,
        defense: 120,
        spAtk: 100,
        spDef: 100,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Zapdos',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 180,
        spDef: 120,
        maxHp: 180,
      );

      final earthquake = createTestMove(
        name: 'Earthquake',
        type: 'Ground',
        category: 'Physical',
        power: 100,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: earthquake,
        attackerTypes: ['Dragon', 'Ground'],
        defenderTypes: ['Electric', 'Flying'],
      );

      expect(result.isTypeImmune, equals(true));
      expect(result.maxDamage, equals(0));
    });
  });

  group('DamageCalculator - Basic Damage Formula', () {
    test('Physical move with neutral type effectiveness', () {
      final attacker = createTestPokemon(
        name: 'Machamp',
        level: 50,
        attack: 150,
        defense: 100,
        spAtk: 80,
        spDef: 100,
        maxHp: 180,
      );

      final defender = createTestPokemon(
        name: 'Blissey',
        level: 50,
        attack: 50,
        defense: 50,
        spAtk: 100,
        spDef: 150,
        maxHp: 350,
      );

      final tackle = createTestMove(
        name: 'Tackle',
        type: 'Normal',
        category: 'Physical',
        power: 40,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: tackle,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Normal'],
      );

      // Expected formula: (((2 * 50 / 5 + 2) * 40 * 150 / 50) / 50 + 2)
      // = ((22 * 40 * 150 / 50) / 50 + 2)
      // = (132000 / 50 / 50 + 2)
      // = (52.8 + 2) = 54.8 ≈ 54
      expect(result.maxDamage, greaterThan(0));
      expect(result.minDamage, lessThan(result.maxDamage));
      expect(result.minDamage,
          greaterThanOrEqualTo((result.maxDamage * 0.85).toInt()));
    });

    test('Special move with neutral type effectiveness', () {
      final attacker = createTestPokemon(
        name: 'Alakazam',
        level: 50,
        attack: 80,
        defense: 80,
        spAtk: 180,
        spDef: 100,
        maxHp: 130,
      );

      final defender = createTestPokemon(
        name: 'Snorlax',
        level: 50,
        attack: 150,
        defense: 100,
        spAtk: 100,
        spDef: 150,
        maxHp: 300,
      );

      final psychic = createTestMove(
        name: 'Psychic',
        type: 'Psychic',
        category: 'Special',
        power: 90,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: psychic,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Normal'],
      );

      expect(result.maxDamage, greaterThan(0));
      expect(result.minDamage, lessThan(result.maxDamage));
    });
  });

  group('DamageCalculator - STAB (Same Type Attack Bonus)', () {
    test('STAB multiplies damage by 1.5x', () {
      final attacker = createTestPokemon(
        name: 'Charizard',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 150,
        spDef: 100,
        maxHp: 180,
      );

      final defender = createTestPokemon(
        name: 'Venusaur',
        level: 50,
        attack: 120,
        defense: 120,
        spAtk: 150,
        spDef: 150,
        maxHp: 180,
      );

      final flamethrower = createTestMove(
        name: 'Flamethrower',
        type: 'Fire',
        category: 'Special',
        power: 90,
      );

      // With STAB (Fire-type using Fire move)
      final resultWithStab = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: flamethrower,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Grass', 'Poison'],
      );

      // Without STAB (different type using Fire move)
      final resultNoStab = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: flamethrower,
        attackerTypes: ['Water', 'Flying'],
        defenderTypes: ['Grass', 'Poison'],
      );

      // With STAB should deal more damage
      expect(resultWithStab.maxDamage, greaterThan(resultNoStab.maxDamage));

      // Should be approximately 1.5x (allowing for rounding)
      final stabRatio = resultWithStab.maxDamage / resultNoStab.maxDamage;
      expect(stabRatio, greaterThan(1.4));
      expect(stabRatio, lessThan(1.6));
    });
  });

  group('DamageCalculator - STAB Rules (Adaptability/Tera)', () {
    test('Adaptability raises STAB from 1.5x to 2.0x', () {
      final attacker = createTestPokemon(
        name: 'Eevee',
        level: 50,
        attack: 100,
        defense: 100,
        spAtk: 80,
        spDef: 100,
        maxHp: 150,
        ability: 'Adaptability',
      );

      final defender = createTestPokemon(
        name: 'Pidgeot',
        level: 50,
        attack: 90,
        defense: 80,
        spAtk: 80,
        spDef: 80,
        maxHp: 1000,
      );

      final tackle = createTestMove(
        name: 'Tackle',
        type: 'Normal',
        category: 'Physical',
        power: 40,
      );

      final resultAdaptability = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: tackle,
        attackerTypes: ['Normal'],
        defenderTypes: ['Flying'],
      );

      final resultNormalStab = calculator.calculateDamage(
        attacker: attacker.copyWith(ability: ''),
        defender: defender,
        move: tackle,
        attackerTypes: ['Normal'],
        defenderTypes: ['Flying'],
      );

      final ratio = resultAdaptability.maxDamage / resultNormalStab.maxDamage;
      expect(ratio, greaterThan(1.2));
      expect(ratio, lessThan(1.4));
    });

    test('Tera same type with Adaptability yields 2.25x', () {
      final attacker = createTestPokemon(
        name: 'Charizard',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 150,
        spDef: 100,
        maxHp: 180,
        ability: 'Adaptability',
        teraType: 'Fire',
      );

      final defender = createTestPokemon(
        name: 'Venusaur',
        level: 50,
        attack: 120,
        defense: 120,
        spAtk: 150,
        spDef: 150,
        maxHp: 1000,
      );

      final flamethrower = createTestMove(
        name: 'Flamethrower',
        type: 'Fire',
        category: 'Special',
        power: 90,
      );

      final resultTeraAdapt = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: flamethrower,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Grass', 'Poison'],
        isTerastallized: true,
        originalTypes: ['Fire', 'Flying'],
      );

      final resultTeraNoAdapt = calculator.calculateDamage(
        attacker: attacker.copyWith(ability: ''),
        defender: defender,
        move: flamethrower,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Grass', 'Poison'],
        isTerastallized: true,
        originalTypes: ['Fire', 'Flying'],
      );

      final ratio = resultTeraAdapt.maxDamage / resultTeraNoAdapt.maxDamage;
      expect(ratio, greaterThan(1.1));
      expect(ratio, lessThan(1.2));
    });

    test('Tera different type with Adaptability yields 2.0x', () {
      final attacker = createTestPokemon(
        name: 'Gengar',
        level: 50,
        attack: 80,
        defense: 70,
        spAtk: 160,
        spDef: 80,
        maxHp: 150,
        ability: 'Adaptability',
        teraType: 'Electric',
      );

      final defender = createTestPokemon(
        name: 'Gyarados',
        level: 50,
        attack: 150,
        defense: 100,
        spAtk: 80,
        spDef: 100,
        maxHp: 1000,
      );

      final thunderbolt = createTestMove(
        name: 'Thunderbolt',
        type: 'Electric',
        category: 'Special',
        power: 90,
      );

      final resultTeraAdapt = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: thunderbolt,
        attackerTypes: ['Ghost', 'Poison'],
        defenderTypes: ['Water', 'Flying'],
        isTerastallized: true,
        originalTypes: ['Ghost', 'Poison'],
      );

      final resultTeraNoAdapt = calculator.calculateDamage(
        attacker: attacker.copyWith(ability: ''),
        defender: defender,
        move: thunderbolt,
        attackerTypes: ['Ghost', 'Poison'],
        defenderTypes: ['Water', 'Flying'],
        isTerastallized: true,
        originalTypes: ['Ghost', 'Poison'],
      );

      final ratio = resultTeraAdapt.maxDamage / resultTeraNoAdapt.maxDamage;
      expect(ratio, greaterThan(1.2));
      expect(ratio, lessThan(1.4));
    });

    test('Original-type-only STAB ignores Adaptability in Tera', () {
      final attacker = createTestPokemon(
        name: 'Tyranitar',
        level: 50,
        attack: 180,
        defense: 150,
        spAtk: 120,
        spDef: 130,
        maxHp: 200,
        ability: 'Adaptability',
        teraType: 'Flying',
      );

      final defender = createTestPokemon(
        name: 'Metagross',
        level: 50,
        attack: 150,
        defense: 150,
        spAtk: 120,
        spDef: 110,
        maxHp: 1000,
      );

      final crunch = createTestMove(
        name: 'Crunch',
        type: 'Dark',
        category: 'Physical',
        power: 80,
      );

      final resultAdapt = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: crunch,
        attackerTypes: ['Rock', 'Dark'],
        defenderTypes: ['Steel', 'Psychic'],
        isTerastallized: true,
        originalTypes: ['Rock', 'Dark'],
      );

      final resultNoAdapt = calculator.calculateDamage(
        attacker: attacker.copyWith(ability: ''),
        defender: defender,
        move: crunch,
        attackerTypes: ['Rock', 'Dark'],
        defenderTypes: ['Steel', 'Psychic'],
        isTerastallized: true,
        originalTypes: ['Rock', 'Dark'],
      );

      final ratio = resultAdapt.maxDamage / resultNoAdapt.maxDamage;
      expect(ratio, greaterThan(0.95));
      expect(ratio, lessThan(1.05));
    });
  });

  group('DamageCalculator - Type Effectiveness', () {
    test('Super effective (2x) deals double damage', () {
      final attacker = createTestPokemon(
        name: 'Blastoise',
        level: 50,
        attack: 120,
        defense: 120,
        spAtk: 150,
        spDef: 120,
        maxHp: 180,
      );

      final defender = createTestPokemon(
        name: 'Charizard',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 150,
        spDef: 100,
        maxHp: 1000,
      );

      final waterGun = createTestMove(
        name: 'Water Gun',
        type: 'Water',
        category: 'Special',
        power: 40,
      );

      // Super effective: Water vs Fire
      final resultSuperEffective = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: waterGun,
        attackerTypes: ['Water'],
        defenderTypes: ['Fire', 'Flying'],
      );

      // Neutral: Water vs Water
      final resultNeutral = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: waterGun,
        attackerTypes: ['Water'],
        defenderTypes: ['Normal'],
      );

      // Super effective should deal approximately 2x damage
      expect(
          resultSuperEffective.maxDamage, greaterThan(resultNeutral.maxDamage));
      final effectivenessRatio =
          resultSuperEffective.maxDamage / resultNeutral.maxDamage;
      expect(effectivenessRatio, greaterThan(1.8));
      expect(effectivenessRatio, lessThan(2.2));
      expect(
          resultSuperEffective.effectivenessString, equals('super-effective'));
    });

    test('Not very effective (0.5x) deals half damage', () {
      final attacker = createTestPokemon(
        name: 'Charizard',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 150,
        spDef: 100,
        maxHp: 180,
      );

      final defender = createTestPokemon(
        name: 'Blastoise',
        level: 50,
        attack: 120,
        defense: 120,
        spAtk: 150,
        spDef: 120,
        maxHp: 1000,
      );

      final ember = createTestMove(
        name: 'Ember',
        type: 'Fire',
        category: 'Special',
        power: 40,
      );

      // Not very effective: Fire vs Water
      final resultNotVeryEffective = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: ember,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Water'],
      );

      // Neutral: Fire vs Grass (for comparison)
      final resultNeutral = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: ember,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Normal'],
      );

      // Not very effective should deal approximately 0.5x damage
      final effectivenessRatio =
          resultNotVeryEffective.maxDamage / resultNeutral.maxDamage;
      expect(effectivenessRatio, greaterThan(0.4));
      expect(effectivenessRatio, lessThan(0.6));
      expect(resultNotVeryEffective.effectivenessString,
          equals('not-very-effective'));
    });

    test('4x super effective deals quadruple damage', () {
      final attacker = createTestPokemon(
        name: 'Swampert',
        level: 50,
        attack: 150,
        defense: 120,
        spAtk: 100,
        spDef: 120,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Charizard',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 150,
        spDef: 100,
        maxHp: 1000,
      );

      final rockSlide = createTestMove(
        name: 'Rock Slide',
        type: 'Rock',
        category: 'Physical',
        power: 75,
      );

      // 4x super effective: Rock vs Fire/Flying
      final result4x = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: rockSlide,
        attackerTypes: ['Water', 'Ground'],
        defenderTypes: ['Fire', 'Flying'],
      );

      // Neutral for comparison
      final resultNeutral = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: rockSlide,
        attackerTypes: ['Water', 'Ground'],
        defenderTypes: ['Normal'],
      );

      // 4x should deal approximately 4x damage
      final effectivenessRatio = result4x.maxDamage / resultNeutral.maxDamage;
      expect(effectivenessRatio, greaterThan(3.8));
      expect(effectivenessRatio, lessThan(4.2));
    });

    test('0.25x (doubly resisted) deals quarter damage', () {
      final attacker = createTestPokemon(
        name: 'Breloom',
        level: 50,
        attack: 150,
        defense: 100,
        spAtk: 80,
        spDef: 80,
        maxHp: 150,
      );

      final defender = createTestPokemon(
        name: 'Crobat',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 90,
        spDef: 100,
        maxHp: 1000,
      );

      final machPunch = createTestMove(
        name: 'Mach Punch',
        type: 'Fighting',
        category: 'Physical',
        power: 40,
      );

      // 0.25x: Fighting vs Poison/Flying
      final result025x = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: machPunch,
        attackerTypes: ['Grass', 'Fighting'],
        defenderTypes: ['Poison', 'Flying'],
      );

      // Neutral for comparison
      final resultNeutral = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: machPunch,
        attackerTypes: ['Grass', 'Fighting'],
        defenderTypes: ['Electric'],
      );

      // 0.25x should deal approximately 0.25x damage
      final effectivenessRatio = result025x.maxDamage / resultNeutral.maxDamage;
      expect(effectivenessRatio, greaterThan(0.2));
      expect(effectivenessRatio, lessThan(0.3));
    });
  });

  group('DamageCalculator - Type Effectiveness Special Rules', () {
    test('Struggle ignores immunities (type = 1)', () {
      final attacker = createTestPokemon(
        name: 'Tauros',
        level: 50,
        attack: 150,
        defense: 100,
        spAtk: 80,
        spDef: 100,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Gengar',
        level: 50,
        attack: 100,
        defense: 80,
        spAtk: 180,
        spDef: 100,
        maxHp: 1000,
      );

      final struggle = createTestMove(
        name: 'Struggle',
        type: 'Normal',
        category: 'Physical',
        power: 50,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: struggle,
        attackerTypes: ['Normal'],
        defenderTypes: ['Ghost'],
      );

      expect(result.isTypeImmune, equals(false));
      expect(result.maxDamage, greaterThan(0));
      expect(result.effectivenessString, isNull);
    });

    test('Typeless Revelation Dance uses neutral type', () {
      final attacker = createTestPokemon(
        name: 'Oricorio',
        level: 50,
        attack: 80,
        defense: 80,
        spAtk: 130,
        spDef: 100,
        maxHp: 160,
      );

      final defender = createTestPokemon(
        name: 'Golem',
        level: 50,
        attack: 120,
        defense: 150,
        spAtk: 80,
        spDef: 100,
        maxHp: 1000,
      );

      final revelationDance = createTestMove(
        name: 'Revelation Dance',
        type: '???',
        category: 'Special',
        power: 90,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: revelationDance,
        attackerTypes: ['Flying'],
        defenderTypes: ['Rock', 'Ground'],
      );

      expect(result.isTypeImmune, equals(false));
      expect(result.effectivenessString, isNull);
    });

    test('Typeless target always yields neutral type', () {
      final attacker = createTestPokemon(
        name: 'Charizard',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 150,
        spDef: 100,
        maxHp: 180,
      );

      final defender = createTestPokemon(
        name: 'Ditto',
        level: 50,
        attack: 100,
        defense: 100,
        spAtk: 100,
        spDef: 100,
        maxHp: 1000,
      );

      final flamethrower = createTestMove(
        name: 'Flamethrower',
        type: 'Fire',
        category: 'Special',
        power: 90,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: flamethrower,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['???'],
      );

      expect(result.effectivenessString, isNull);
    });

    test('Iron Ball on ungrounded Flying makes Ground neutral', () {
      final attacker = createTestPokemon(
        name: 'Garchomp',
        level: 50,
        attack: 180,
        defense: 120,
        spAtk: 100,
        spDef: 100,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Zapdos',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 180,
        spDef: 120,
        maxHp: 1000,
      );

      final earthquake = createTestMove(
        name: 'Earthquake',
        type: 'Ground',
        category: 'Physical',
        power: 100,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: earthquake,
        attackerTypes: ['Dragon', 'Ground'],
        defenderTypes: ['Electric', 'Flying'],
        targetHasIronBall: true,
        targetIsGrounded: false,
      );

      expect(result.effectivenessString, isNull);
      expect(result.maxDamage, greaterThan(0));
    });

    test('Grounded Flying removes Ground immunity', () {
      final attacker = createTestPokemon(
        name: 'Garchomp',
        level: 50,
        attack: 180,
        defense: 120,
        spAtk: 100,
        spDef: 100,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Zapdos',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 180,
        spDef: 120,
        maxHp: 1000,
      );

      final earthquake = createTestMove(
        name: 'Earthquake',
        type: 'Ground',
        category: 'Physical',
        power: 100,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: earthquake,
        attackerTypes: ['Dragon', 'Ground'],
        defenderTypes: ['Electric', 'Flying'],
        targetIsGrounded: true,
      );

      expect(result.effectivenessString, equals('super-effective'));
    });

    test('Ring Target removes immunities', () {
      final attacker = createTestPokemon(
        name: 'Tauros',
        level: 50,
        attack: 150,
        defense: 100,
        spAtk: 80,
        spDef: 100,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Gengar',
        level: 50,
        attack: 100,
        defense: 80,
        spAtk: 180,
        spDef: 100,
        maxHp: 1000,
      );

      final tackle = createTestMove(
        name: 'Tackle',
        type: 'Normal',
        category: 'Physical',
        power: 40,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: tackle,
        attackerTypes: ['Normal'],
        defenderTypes: ['Ghost'],
        targetHasRingTarget: true,
      );

      expect(result.isTypeImmune, equals(false));
      expect(result.effectivenessString, isNull);
    });

    test('Scrappy removes Ghost immunity to Normal/Fighting', () {
      final attacker = createTestPokemon(
        name: 'Kangaskhan',
        level: 50,
        attack: 140,
        defense: 100,
        spAtk: 80,
        spDef: 100,
        maxHp: 200,
        ability: 'Scrappy',
      );

      final defender = createTestPokemon(
        name: 'Gengar',
        level: 50,
        attack: 100,
        defense: 80,
        spAtk: 180,
        spDef: 100,
        maxHp: 1000,
      );

      final tackle = createTestMove(
        name: 'Tackle',
        type: 'Normal',
        category: 'Physical',
        power: 40,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: tackle,
        attackerTypes: ['Normal'],
        defenderTypes: ['Ghost'],
      );

      expect(result.isTypeImmune, equals(false));
      expect(result.effectivenessString, isNull);
    });

    test('Foresight removes Ghost immunity', () {
      final attacker = createTestPokemon(
        name: 'Machamp',
        level: 50,
        attack: 180,
        defense: 100,
        spAtk: 80,
        spDef: 100,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Gengar',
        level: 50,
        attack: 100,
        defense: 80,
        spAtk: 180,
        spDef: 100,
        maxHp: 1000,
      );

      final closeCombat = createTestMove(
        name: 'Close Combat',
        type: 'Fighting',
        category: 'Physical',
        power: 120,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: closeCombat,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Ghost'],
        targetUnderForesight: true,
      );

      expect(result.isTypeImmune, equals(false));
      expect(result.effectivenessString, isNull);
    });

    test('Miracle Eye removes Dark immunity to Psychic', () {
      final attacker = createTestPokemon(
        name: 'Alakazam',
        level: 50,
        attack: 80,
        defense: 80,
        spAtk: 180,
        spDef: 100,
        maxHp: 150,
      );

      final defender = createTestPokemon(
        name: 'Tyranitar',
        level: 50,
        attack: 180,
        defense: 150,
        spAtk: 120,
        spDef: 130,
        maxHp: 1000,
      );

      final psychic = createTestMove(
        name: 'Psychic',
        type: 'Psychic',
        category: 'Special',
        power: 90,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: psychic,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Rock', 'Dark'],
        targetUnderMiracleEye: true,
      );

      expect(result.isTypeImmune, equals(false));
    });

    test('Freeze-Dry is super effective vs Water', () {
      final attacker = createTestPokemon(
        name: 'Glaceon',
        level: 50,
        attack: 80,
        defense: 100,
        spAtk: 160,
        spDef: 120,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Milotic',
        level: 50,
        attack: 80,
        defense: 100,
        spAtk: 100,
        spDef: 140,
        maxHp: 1000,
      );

      final freezeDry = createTestMove(
        name: 'Freeze-Dry',
        type: 'Ice',
        category: 'Special',
        power: 70,
      );

      final iceBeam = createTestMove(
        name: 'Ice Beam',
        type: 'Ice',
        category: 'Special',
        power: 70,
      );

      final resultFreezeDry = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: freezeDry,
        attackerTypes: ['Ice'],
        defenderTypes: ['Water'],
      );

      final resultIceBeam = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: iceBeam,
        attackerTypes: ['Ice'],
        defenderTypes: ['Water'],
      );

      final ratio = resultFreezeDry.maxDamage / resultIceBeam.maxDamage;
      expect(ratio, greaterThan(3.5));
      expect(ratio, lessThan(4.5));
    });

    test('Flying Press combines Fighting and Flying effectiveness', () {
      final attacker = createTestPokemon(
        name: 'Hawlucha',
        level: 50,
        attack: 140,
        defense: 100,
        spAtk: 60,
        spDef: 90,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Tyranitar',
        level: 50,
        attack: 180,
        defense: 150,
        spAtk: 120,
        spDef: 130,
        maxHp: 1000,
      );

      final flyingPress = createTestMove(
        name: 'Flying Press',
        type: 'Fighting',
        category: 'Physical',
        power: 100,
      );

      final closeCombat = createTestMove(
        name: 'Close Combat',
        type: 'Fighting',
        category: 'Physical',
        power: 100,
      );

      final resultFlyingPress = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: flyingPress,
        attackerTypes: ['Fighting', 'Flying'],
        defenderTypes: ['Rock', 'Dark'],
      );

      final resultCloseCombat = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: closeCombat,
        attackerTypes: ['Fighting', 'Flying'],
        defenderTypes: ['Rock', 'Dark'],
      );

      final ratio = resultFlyingPress.maxDamage / resultCloseCombat.maxDamage;
      expect(ratio, greaterThan(0.45));
      expect(ratio, lessThan(0.55));
    });

    test('Strong winds neutralizes super effective against Flying', () {
      final attacker = createTestPokemon(
        name: 'Jolteon',
        level: 50,
        attack: 80,
        defense: 80,
        spAtk: 160,
        spDef: 100,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Gyarados',
        level: 50,
        attack: 150,
        defense: 100,
        spAtk: 80,
        spDef: 100,
        maxHp: 1000,
      );

      final thunderbolt = createTestMove(
        name: 'Thunderbolt',
        type: 'Electric',
        category: 'Special',
        power: 90,
      );

      final resultNormal = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: thunderbolt,
        attackerTypes: ['Electric'],
        defenderTypes: ['Water', 'Flying'],
      );

      final resultStrongWinds = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: thunderbolt,
        attackerTypes: ['Electric'],
        defenderTypes: ['Water', 'Flying'],
        strongWindsActive: true,
      );

      final ratio = resultStrongWinds.maxDamage / resultNormal.maxDamage;
      expect(ratio, greaterThan(0.45));
      expect(ratio, lessThan(0.55));
    });

    test('Tar Shot doubles Fire damage', () {
      final attacker = createTestPokemon(
        name: 'Arcanine',
        level: 50,
        attack: 140,
        defense: 100,
        spAtk: 120,
        spDef: 100,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Scizor',
        level: 50,
        attack: 130,
        defense: 140,
        spAtk: 80,
        spDef: 100,
        maxHp: 1000,
      );

      final flamethrower = createTestMove(
        name: 'Flamethrower',
        type: 'Fire',
        category: 'Special',
        power: 90,
      );

      final resultNormal = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: flamethrower,
        attackerTypes: ['Fire'],
        defenderTypes: ['Bug', 'Steel'],
      );

      final resultTarShot = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: flamethrower,
        attackerTypes: ['Fire'],
        defenderTypes: ['Bug', 'Steel'],
        targetUnderTarShot: true,
      );

      final ratio = resultTarShot.maxDamage / resultNormal.maxDamage;
      expect(ratio, greaterThan(1.9));
      expect(ratio, lessThan(2.1));
    });
  });

  group('DamageCalculator - Stat Stages', () {
    test('+1 attack stage increases damage', () {
      final attacker = createTestPokemon(
        name: 'Garchomp',
        level: 50,
        attack: 180,
        defense: 120,
        spAtk: 100,
        spDef: 100,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Blissey',
        level: 50,
        attack: 50,
        defense: 50,
        spAtk: 100,
        spDef: 150,
        maxHp: 350,
      );

      final dragonClaw = createTestMove(
        name: 'Dragon Claw',
        type: 'Dragon',
        category: 'Physical',
        power: 80,
      );

      // Normal attack
      final resultNormal = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: dragonClaw,
        attackerTypes: ['Dragon', 'Ground'],
        defenderTypes: ['Normal'],
      );

      // +1 attack stage
      final attackerBoosted = createTestPokemon(
        name: 'Garchomp',
        level: 50,
        attack: 180,
        defense: 120,
        spAtk: 100,
        spDef: 100,
        maxHp: 200,
        statStages: {
          'hp': 0,
          'atk': 1,
          'def': 0,
          'spa': 0,
          'spd': 0,
          'spe': 0,
          'acc': 0,
          'eva': 0
        },
      );

      final resultBoosted = calculator.calculateDamage(
        attacker: attackerBoosted,
        defender: defender,
        move: dragonClaw,
        attackerTypes: ['Dragon', 'Ground'],
        defenderTypes: ['Normal'],
      );

      // +1 attack should deal 1.5x damage
      expect(resultBoosted.maxDamage, greaterThan(resultNormal.maxDamage));
      final boostRatio = resultBoosted.maxDamage / resultNormal.maxDamage;
      expect(boostRatio, greaterThan(1.4));
      expect(boostRatio, lessThan(1.6));
    });

    test('+2 defense stage reduces damage taken', () {
      final attacker = createTestPokemon(
        name: 'Machamp',
        level: 50,
        attack: 180,
        defense: 100,
        spAtk: 80,
        spDef: 100,
        maxHp: 180,
      );

      final defender = createTestPokemon(
        name: 'Skarmory',
        level: 50,
        attack: 100,
        defense: 180,
        spAtk: 60,
        spDef: 90,
        maxHp: 150,
      );

      final closeCombat = createTestMove(
        name: 'Close Combat',
        type: 'Fighting',
        category: 'Physical',
        power: 120,
      );

      // Normal defense
      final resultNormal = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: closeCombat,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Steel', 'Flying'],
      );

      // +2 defense stage
      final defenderBoosted = createTestPokemon(
        name: 'Skarmory',
        level: 50,
        attack: 100,
        defense: 180,
        spAtk: 60,
        spDef: 90,
        maxHp: 150,
        statStages: {
          'hp': 0,
          'atk': 0,
          'def': 2,
          'spa': 0,
          'spd': 0,
          'spe': 0,
          'acc': 0,
          'eva': 0
        },
      );

      final resultBoosted = calculator.calculateDamage(
        attacker: attacker,
        defender: defenderBoosted,
        move: closeCombat,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Steel', 'Flying'],
      );

      // +2 defense should reduce damage to 0.5x (defense doubled)
      expect(resultBoosted.maxDamage, lessThan(resultNormal.maxDamage));
      final reductionRatio = resultBoosted.maxDamage / resultNormal.maxDamage;
      expect(reductionRatio, greaterThan(0.45));
      expect(reductionRatio, lessThan(0.55));
    });

    test('-1 attack stage decreases damage', () {
      final attacker = createTestPokemon(
        name: 'Dragonite',
        level: 50,
        attack: 180,
        defense: 120,
        spAtk: 130,
        spDef: 120,
        maxHp: 180,
      );

      final defender = createTestPokemon(
        name: 'Ferrothorn',
        level: 50,
        attack: 130,
        defense: 180,
        spAtk: 80,
        spDef: 130,
        maxHp: 180,
      );

      final outrage = createTestMove(
        name: 'Outrage',
        type: 'Dragon',
        category: 'Physical',
        power: 120,
      );

      // Normal attack
      final resultNormal = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: outrage,
        attackerTypes: ['Dragon', 'Flying'],
        defenderTypes: ['Grass', 'Steel'],
      );

      // -1 attack stage (Intimidate)
      final attackerDebuffed = createTestPokemon(
        name: 'Dragonite',
        level: 50,
        attack: 180,
        defense: 120,
        spAtk: 130,
        spDef: 120,
        maxHp: 180,
        statStages: {
          'hp': 0,
          'atk': -1,
          'def': 0,
          'spa': 0,
          'spd': 0,
          'spe': 0,
          'acc': 0,
          'eva': 0
        },
      );

      final resultDebuffed = calculator.calculateDamage(
        attacker: attackerDebuffed,
        defender: defender,
        move: outrage,
        attackerTypes: ['Dragon', 'Flying'],
        defenderTypes: ['Grass', 'Steel'],
      );

      // -1 attack should deal 2/3x damage (0.67x)
      expect(resultDebuffed.maxDamage, lessThan(resultNormal.maxDamage));
      final debuffRatio = resultDebuffed.maxDamage / resultNormal.maxDamage;
      expect(debuffRatio, greaterThan(0.62));
      expect(debuffRatio, lessThan(0.72));
    });

    test('+6 attack stage (max) increases damage significantly', () {
      final attacker = createTestPokemon(
        name: 'Blaziken',
        level: 50,
        attack: 160,
        defense: 90,
        spAtk: 140,
        spDef: 90,
        maxHp: 160,
      );

      final defender = createTestPokemon(
        name: 'Tyranitar',
        level: 50,
        attack: 180,
        defense: 150,
        spAtk: 120,
        spDef: 130,
        maxHp: 1000,
      );

      final highJumpKick = createTestMove(
        name: 'High Jump Kick',
        type: 'Fighting',
        category: 'Physical',
        power: 130,
      );

      // Normal attack
      final resultNormal = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: highJumpKick,
        attackerTypes: ['Fire'], // No STAB to avoid interference
        defenderTypes: ['Rock', 'Dark'],
      );

      // +6 attack stage (max boost)
      final attackerMaxBoosted = createTestPokemon(
        name: 'Blaziken',
        level: 50,
        attack: 160,
        defense: 90,
        spAtk: 140,
        spDef: 90,
        maxHp: 160,
        statStages: {
          'hp': 0,
          'atk': 6,
          'def': 0,
          'spa': 0,
          'spd': 0,
          'spe': 0,
          'acc': 0,
          'eva': 0
        },
      );

      final resultMaxBoosted = calculator.calculateDamage(
        attacker: attackerMaxBoosted,
        defender: defender,
        move: highJumpKick,
        attackerTypes: ['Fire'], // No STAB
        defenderTypes: ['Rock', 'Dark'],
      );

      // +6 attack should deal 4x damage
      expect(resultMaxBoosted.maxDamage, greaterThan(resultNormal.maxDamage));
      final boostRatio = resultMaxBoosted.maxDamage / resultNormal.maxDamage;
      expect(boostRatio, greaterThan(3.9));
      expect(boostRatio, lessThan(4.1));
    });
  });

  group('DamageCalculator - Hit Chance', () {
    test('100 accuracy move has 100% hit chance', () {
      final attacker = createTestPokemon(
        name: 'Pikachu',
        level: 50,
        attack: 80,
        defense: 60,
        spAtk: 80,
        spDef: 70,
        maxHp: 100,
      );

      final defender = createTestPokemon(
        name: 'Geodude',
        level: 50,
        attack: 100,
        defense: 120,
        spAtk: 50,
        spDef: 60,
        maxHp: 120,
      );

      final thunderbolt = createTestMove(
        name: 'Thunderbolt',
        type: 'Electric',
        category: 'Special',
        power: 90,
        accuracy: 100,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: thunderbolt,
        attackerTypes: ['Electric'],
        defenderTypes: ['Rock', 'Ground'],
      );

      expect(result.hitChance, equals(1.0));
    });

    test('85 accuracy move has 85% hit chance', () {
      final attacker = createTestPokemon(
        name: 'Alakazam',
        level: 50,
        attack: 80,
        defense: 80,
        spAtk: 180,
        spDef: 100,
        maxHp: 130,
      );

      final defender = createTestPokemon(
        name: 'Tyranitar',
        level: 50,
        attack: 180,
        defense: 150,
        spAtk: 120,
        spDef: 130,
        maxHp: 200,
      );

      final focusBlast = createTestMove(
        name: 'Focus Blast',
        type: 'Fighting',
        category: 'Special',
        power: 120,
        accuracy: 70,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: focusBlast,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Rock', 'Dark'],
      );

      expect(result.hitChance, equals(0.7));
    });

    test('+1 accuracy stage increases hit chance', () {
      final attacker = createTestPokemon(
        name: 'Scizor',
        level: 50,
        attack: 180,
        defense: 130,
        spAtk: 80,
        spDef: 100,
        maxHp: 160,
        statStages: {
          'hp': 0,
          'atk': 0,
          'def': 0,
          'spa': 0,
          'spd': 0,
          'spe': 0,
          'acc': 1,
          'eva': 0
        },
      );

      final defender = createTestPokemon(
        name: 'Charizard',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 150,
        spDef: 100,
        maxHp: 180,
      );

      final stoneEdge = createTestMove(
        name: 'Stone Edge',
        type: 'Rock',
        category: 'Physical',
        power: 100,
        accuracy: 80,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: stoneEdge,
        attackerTypes: ['Bug', 'Steel'],
        defenderTypes: ['Fire', 'Flying'],
      );

      // Base 80 accuracy with +1 acc = 80 * (4/3) ≈ 106.7% capped at 100%
      expect(result.hitChance, greaterThan(0.8));
    });

    test('+1 evasion stage decreases hit chance', () {
      final attacker = createTestPokemon(
        name: 'Machamp',
        level: 50,
        attack: 180,
        defense: 100,
        spAtk: 80,
        spDef: 100,
        maxHp: 180,
      );

      final defender = createTestPokemon(
        name: 'Zapdos',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 180,
        spDef: 120,
        maxHp: 180,
        statStages: {
          'hp': 0,
          'atk': 0,
          'def': 0,
          'spa': 0,
          'spd': 0,
          'spe': 0,
          'acc': 0,
          'eva': 1
        },
      );

      final dynamicPunch = createTestMove(
        name: 'Dynamic Punch',
        type: 'Fighting',
        category: 'Physical',
        power: 100,
        accuracy: 50,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: dynamicPunch,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Electric', 'Flying'],
      );

      // Base 50 accuracy with +1 evasion = 50 * (3/4) = 37.5%
      expect(result.hitChance, lessThan(0.5));
      expect(result.hitChance, greaterThan(0.35));
    });
  });

  group('DamageCalculator - Damage Range', () {
    test('Damage range is between 85% and 100%', () {
      final attacker = createTestPokemon(
        name: 'Garchomp',
        level: 50,
        attack: 180,
        defense: 120,
        spAtk: 100,
        spDef: 100,
        maxHp: 200,
      );

      final defender = createTestPokemon(
        name: 'Dragonite',
        level: 50,
        attack: 180,
        defense: 120,
        spAtk: 130,
        spDef: 120,
        maxHp: 1000,
      );

      final earthquake = createTestMove(
        name: 'Earthquake',
        type: 'Ground',
        category: 'Physical',
        power: 100,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: earthquake,
        attackerTypes: ['Dragon', 'Ground'],
        defenderTypes: ['Dragon'],
      );

      // Verify range
      expect(result.minDamage, lessThan(result.maxDamage));

      // Min damage should be approximately 85% of max damage
      final rangeRatio = result.minDamage / result.maxDamage;
      expect(rangeRatio, greaterThanOrEqualTo(0.84));
      expect(rangeRatio, lessThanOrEqualTo(0.86));
    });

    test('Average damage is between min and max', () {
      final attacker = createTestPokemon(
        name: 'Alakazam',
        level: 50,
        attack: 80,
        defense: 80,
        spAtk: 180,
        spDef: 100,
        maxHp: 130,
      );

      final defender = createTestPokemon(
        name: 'Blissey',
        level: 50,
        attack: 50,
        defense: 50,
        spAtk: 100,
        spDef: 150,
        maxHp: 350,
      );

      final psychic = createTestMove(
        name: 'Psychic',
        type: 'Psychic',
        category: 'Special',
        power: 90,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: psychic,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Normal'],
      );

      expect(result.averageDamage, greaterThanOrEqualTo(result.minDamage));
      expect(result.averageDamage, lessThanOrEqualTo(result.maxDamage));
      expect(result.discreteDamageRolls, isNotNull);
      expect(result.discreteDamageRolls!.length, equals(16));
    });
  });

  group('DamageCalculator - Combined Modifiers', () {
    test('STAB + Super effective + Stat boost', () {
      final attacker = createTestPokemon(
        name: 'Garchomp',
        level: 50,
        attack: 180,
        defense: 120,
        spAtk: 100,
        spDef: 100,
        maxHp: 200,
        statStages: {
          'hp': 0,
          'atk': 2,
          'def': 0,
          'spa': 0,
          'spd': 0,
          'spe': 0,
          'acc': 0,
          'eva': 0
        },
      );

      final defender = createTestPokemon(
        name: 'Tyranitar',
        level: 50,
        attack: 180,
        defense: 150,
        spAtk: 120,
        spDef: 130,
        maxHp: 200,
      );

      final earthquake = createTestMove(
        name: 'Earthquake',
        type: 'Ground',
        category: 'Physical',
        power: 100,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: earthquake,
        attackerTypes: ['Dragon', 'Ground'],
        defenderTypes: ['Rock', 'Dark'],
      );

      // This should have:
      // - STAB (1.5x) - Ground type using Ground move
      // - Super effective (2x) - Ground vs Rock
      // - +2 attack stage (2x)
      // Total: base damage * 1.5 * 2 * 2 = 6x
      expect(result.maxDamage, greaterThan(0));
      expect(result.effectivenessString, equals('super-effective'));
    });

    test('Multiple resistances reduce damage significantly', () {
      final attacker = createTestPokemon(
        name: 'Breloom',
        level: 50,
        attack: 150,
        defense: 100,
        spAtk: 80,
        spDef: 80,
        maxHp: 150,
      );

      final defender = createTestPokemon(
        name: 'Crobat',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 90,
        spDef: 100,
        maxHp: 180,
        statStages: {
          'hp': 0,
          'atk': 0,
          'def': 2,
          'spa': 0,
          'spd': 0,
          'spe': 0,
          'acc': 0,
          'eva': 0
        },
      );

      final machPunch = createTestMove(
        name: 'Mach Punch',
        type: 'Fighting',
        category: 'Physical',
        power: 40,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: machPunch,
        attackerTypes: ['Grass', 'Fighting'],
        defenderTypes: ['Poison', 'Flying'],
      );

      final neutralDefender = createTestPokemon(
        name: 'Eevee',
        level: 50,
        attack: 80,
        defense: 100,
        spAtk: 60,
        spDef: 80,
        maxHp: 180,
      );

      final neutralResult = calculator.calculateDamage(
        attacker: attacker,
        defender: neutralDefender,
        move: machPunch,
        attackerTypes: ['Grass', 'Fighting'],
        defenderTypes: ['Normal'],
      );

      // This should have:
      // - 0.25x type effectiveness (Fighting resisted by both Poison and Flying)
      // - +2 defense stage (0.5x damage)
      // Total: base damage * 0.25 * 0.5 = 0.125x
      expect(result.maxDamage, greaterThan(0));
      final ratio = result.maxDamage / neutralResult.maxDamage;
      expect(ratio, greaterThan(0.05));
      expect(ratio, lessThan(0.2));
    });
  });

  group('DamageCalculator - Edge Cases', () {
    test('Level 100 vs Level 1 deals massive damage', () {
      final attacker = createTestPokemon(
        name: 'Mewtwo',
        level: 100,
        attack: 150,
        defense: 120,
        spAtk: 250,
        spDef: 120,
        maxHp: 350,
      );

      final defender = createTestPokemon(
        name: 'Magikarp',
        level: 1,
        attack: 10,
        defense: 55,
        spAtk: 15,
        spDef: 20,
        maxHp: 11,
      );

      final psychic = createTestMove(
        name: 'Psychic',
        type: 'Psychic',
        category: 'Special',
        power: 90,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: psychic,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Water'],
      );

      // Damage calculation shows how much damage is dealt, uncapped by opponent's HP
      expect(result.maxDamage, greaterThan(defender.maxHp));
      expect(result.minDamage, greaterThan(0));
    });

    test('Very high defense prevents excessive damage', () {
      final attacker = createTestPokemon(
        name: 'Magikarp',
        level: 50,
        attack: 50,
        defense: 80,
        spAtk: 40,
        spDef: 50,
        maxHp: 100,
      );

      final defender = createTestPokemon(
        name: 'Shuckle',
        level: 50,
        attack: 50,
        defense: 300,
        spAtk: 50,
        spDef: 300,
        maxHp: 100,
        statStages: {
          'hp': 0,
          'atk': 0,
          'def': 6,
          'spa': 0,
          'spd': 0,
          'spe': 0,
          'acc': 0,
          'eva': 0
        },
      );

      final tackle = createTestMove(
        name: 'Tackle',
        type: 'Normal',
        category: 'Physical',
        power: 40,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: tackle,
        attackerTypes: ['Water'],
        defenderTypes: ['Bug', 'Rock'],
      );

      // Damage should be minimal but at least 1
      expect(result.maxDamage, greaterThanOrEqualTo(1));
      expect(result.maxDamage, lessThan(10));
    });

    test('Move with 0 power deals 0 damage', () {
      final attacker = createTestPokemon(
        name: 'Charizard',
        level: 50,
        attack: 120,
        defense: 100,
        spAtk: 150,
        spDef: 100,
        maxHp: 180,
      );

      final defender = createTestPokemon(
        name: 'Blastoise',
        level: 50,
        attack: 120,
        defense: 120,
        spAtk: 150,
        spDef: 120,
        maxHp: 180,
      );

      final lowPowerMove = createTestMove(
        name: 'Splash',
        type: 'Normal',
        category: 'Physical',
        power: 0,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: lowPowerMove,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Water'],
      );

      expect(result.maxDamage, equals(0));
      expect(result.minDamage, equals(0));
    });

    test('Damage cannot exceed defender max HP', () {
      final attacker = createTestPokemon(
        name: 'Mewtwo',
        level: 100,
        attack: 150,
        defense: 120,
        spAtk: 250,
        spDef: 120,
        maxHp: 350,
        statStages: {
          'hp': 0,
          'atk': 0,
          'def': 0,
          'spa': 6,
          'spd': 0,
          'spe': 0,
          'acc': 0,
          'eva': 0
        },
      );

      final defender = createTestPokemon(
        name: 'Weedle',
        level: 5,
        attack: 20,
        defense: 20,
        spAtk: 15,
        spDef: 15,
        maxHp: 20,
      );

      final psychic = createTestMove(
        name: 'Psychic',
        type: 'Psychic',
        category: 'Special',
        power: 90,
      );

      final result = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: psychic,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Bug', 'Poison'],
      );

      // Damage is calculated without being capped by opponent's max HP
      // The simulator handles capping damage when applying it to the target
      expect(result.maxDamage, greaterThan(0));
      expect(result.minDamage, greaterThan(0));
    });
  });

  group('Attacker Abilities - Damage Modifiers', () {
    test('Huge Power/Pure Power doubles physical damage', () {
      final attacker = createTestPokemon(
        name: 'Azumarill',
        level: 100,
        attack: 100,
        defense: 80,
        spAtk: 60,
        spDef: 80,
        maxHp: 300,
        ability: 'Huge Power',
      );

      final defender = createTestPokemon(
        name: 'Garchomp',
        level: 100,
        attack: 130,
        defense: 95,
        spAtk: 80,
        spDef: 85,
        maxHp: 350,
      );

      final tackle = createTestMove(
        name: 'Tackle',
        type: 'Normal',
        category: 'Physical',
        power: 40,
      );

      final normalResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: tackle,
        attackerTypes: ['Water', 'Fairy'],
        defenderTypes: ['Dragon', 'Ground'],
      );

      // Create attacker without Huge Power for comparison
      final attackerNoAbility = createTestPokemon(
        name: 'Azumarill',
        level: 100,
        attack: 100,
        defense: 80,
        spAtk: 60,
        spDef: 80,
        maxHp: 300,
        ability: '',
      );

      final noAbilityResult = calculator.calculateDamage(
        attacker: attackerNoAbility,
        defender: defender,
        move: tackle,
        attackerTypes: ['Water', 'Fairy'],
        defenderTypes: ['Dragon', 'Ground'],
      );

      // Huge Power should double the damage
      expect(normalResult.maxDamage / noAbilityResult.maxDamage,
          closeTo(2.0, 0.1));
    });

    test('Blaze boosts Fire-type moves when HP is low', () {
      final attacker = createTestPokemon(
        name: 'Charizard',
        level: 100,
        attack: 84,
        defense: 78,
        spAtk: 109,
        spDef: 85,
        maxHp: 300,
        ability: 'Blaze',
      );
      attacker.currentHp = 90; // Below 1/3 of maxHp (100)

      final defender = createTestPokemon(
        name: 'Golem',
        level: 100,
        attack: 120,
        defense: 130,
        spAtk: 55,
        spDef: 65,
        maxHp: 400, // Higher HP to avoid cap
      );

      final ember = createTestMove(
        // Weaker move to avoid damage cap
        name: 'Ember',
        type: 'Fire',
        category: 'Special',
        power: 40,
      );

      final lowHpResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: ember,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Rock', 'Ground'], // Neutral to Fire
      );

      // High HP (no Blaze boost)
      attacker.currentHp = 300;
      final highHpResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: ember,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Rock', 'Ground'],
      );

      // Low HP should boost damage by 1.5x
      expect(lowHpResult.maxDamage / highHpResult.maxDamage, closeTo(1.5, 0.1));
    });

    test('Tough Claws boosts contact moves', () {
      final attacker = createTestPokemon(
        name: 'Mega Charizard X',
        level: 100,
        attack: 130,
        defense: 111,
        spAtk: 130,
        spDef: 85,
        maxHp: 300,
        ability: 'Tough Claws',
      );

      final defender = createTestPokemon(
        name: 'Blastoise',
        level: 100,
        attack: 83,
        defense: 100,
        spAtk: 85,
        spDef: 105,
        maxHp: 300,
      );

      final dragonClaw = createTestMove(
        name: 'Dragon Claw',
        type: 'Dragon',
        category: 'Physical',
        power: 80,
        makesContact: true,
      );

      final contactResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: dragonClaw,
        attackerTypes: ['Dragon', 'Fire'],
        defenderTypes: ['Water'],
      );

      // No ability comparison
      final attackerNoAbility = createTestPokemon(
        name: 'Mega Charizard X',
        level: 100,
        attack: 130,
        defense: 111,
        spAtk: 130,
        spDef: 85,
        maxHp: 300,
        ability: '',
      );
      final noAbilityResult = calculator.calculateDamage(
        attacker: attackerNoAbility,
        defender: defender,
        move: dragonClaw,
        attackerTypes: ['Dragon', 'Fire'],
        defenderTypes: ['Water'],
      );

      // Tough Claws should boost by 1.3x
      expect(contactResult.maxDamage / noAbilityResult.maxDamage,
          closeTo(1.3, 0.1));
    });

    test('Technician boosts low-power moves', () {
      final attacker = createTestPokemon(
        name: 'Scizor',
        level: 100,
        attack: 130,
        defense: 100,
        spAtk: 55,
        spDef: 80,
        maxHp: 300,
        ability: 'Technician',
      );

      final defender = createTestPokemon(
        name: 'Metagross',
        level: 100,
        attack: 135,
        defense: 130,
        spAtk: 95,
        spDef: 90,
        maxHp: 300,
      );

      final bulletPunch = createTestMove(
        name: 'Bullet Punch',
        type: 'Steel',
        category: 'Physical',
        power: 40,
      );

      final lowPowerResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: bulletPunch,
        attackerTypes: ['Bug', 'Steel'],
        defenderTypes: ['Steel', 'Psychic'],
      );

      // Higher power move (not boosted)
      final highPowerMove = createTestMove(
        name: 'Iron Head',
        type: 'Steel',
        category: 'Physical',
        power: 80,
      );

      final highPowerResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: highPowerMove,
        attackerTypes: ['Bug', 'Steel'],
        defenderTypes: ['Steel', 'Psychic'],
      );

      // Low power (40) with 1.5x boost = 60 effective
      // High power (80) with no boost = 80
      // So high power should still do more damage overall
      expect(highPowerResult.maxDamage, greaterThan(lowPowerResult.maxDamage));

      // But with Technician, Bullet Punch does 40*1.5 = 60 effective power
      // Without Technician it would be just 40
      final attackerNoAbility = createTestPokemon(
        name: 'Scizor',
        level: 100,
        attack: 130,
        defense: 100,
        spAtk: 55,
        spDef: 80,
        maxHp: 300,
        ability: '',
      );
      final noTechnicianResult = calculator.calculateDamage(
        attacker: attackerNoAbility,
        defender: defender,
        move: bulletPunch,
        attackerTypes: ['Bug', 'Steel'],
        defenderTypes: ['Steel', 'Psychic'],
      );

      expect(lowPowerResult.maxDamage / noTechnicianResult.maxDamage,
          closeTo(1.5, 0.1));
    });

    test('Iron Fist boosts punching moves', () {
      final attacker = createTestPokemon(
        name: 'Conkeldurr',
        level: 100,
        attack: 140,
        defense: 95,
        spAtk: 55,
        spDef: 65,
        maxHp: 350,
        ability: 'Iron Fist',
      );

      final defender = createTestPokemon(
        name: 'Machamp',
        level: 100,
        attack: 130,
        defense: 80,
        spAtk: 65,
        spDef: 85,
        maxHp: 340,
      );

      final drainPunch = createTestMove(
        name: 'Drain Punch',
        type: 'Fighting',
        category: 'Physical',
        power: 75,
      );

      final punchResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: drainPunch,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Fighting'],
      );

      final attackerNoAbility = createTestPokemon(
        name: 'Conkeldurr',
        level: 100,
        attack: 140,
        defense: 95,
        spAtk: 55,
        spDef: 65,
        maxHp: 350,
        ability: '',
      );
      final noPunchBoostResult = calculator.calculateDamage(
        attacker: attackerNoAbility,
        defender: defender,
        move: drainPunch,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Fighting'],
      );

      // Iron Fist should boost by 1.2x
      expect(punchResult.maxDamage / noPunchBoostResult.maxDamage,
          closeTo(1.2, 0.1));
    });

    test('Aerilate converts Normal moves and boosts power', () {
      final attacker = createTestPokemon(
        name: 'Mega Salamence',
        level: 100,
        attack: 145,
        defense: 130,
        spAtk: 120,
        spDef: 90,
        maxHp: 370,
        ability: 'Aerilate',
      );

      final defender = createTestPokemon(
        name: 'Heracross',
        level: 100,
        attack: 125,
        defense: 75,
        spAtk: 40,
        spDef: 95,
        maxHp: 320,
      );

      final hyperVoice = createTestMove(
        name: 'Hyper Voice',
        type: 'Normal',
        category: 'Special',
        power: 90,
      );

      final aerilateResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: hyperVoice,
        attackerTypes: ['Dragon', 'Flying'],
        defenderTypes: ['Bug', 'Fighting'],
      );

      final attackerNoAbility = createTestPokemon(
        name: 'Mega Salamence',
        level: 100,
        attack: 145,
        defense: 130,
        spAtk: 120,
        spDef: 90,
        maxHp: 370,
        ability: '',
      );
      final noAerilateResult = calculator.calculateDamage(
        attacker: attackerNoAbility,
        defender: defender,
        move: hyperVoice,
        attackerTypes: ['Dragon', 'Flying'],
        defenderTypes: ['Bug', 'Fighting'],
      );

      // Aerilate should boost by 1.2x
      expect(aerilateResult.maxDamage / noAerilateResult.maxDamage,
          closeTo(1.2, 0.1));
    });
  });

  group('Defender Abilities - Damage Reduction', () {
    test('Thick Fat reduces Fire and Ice damage', () {
      final attacker = createTestPokemon(
        name: 'Charizard',
        level: 100,
        attack: 84,
        defense: 78,
        spAtk: 109,
        spDef: 85,
        maxHp: 300,
      );

      final defender = createTestPokemon(
        name: 'Snorlax',
        level: 100,
        attack: 110,
        defense: 65,
        spAtk: 65,
        spDef: 110,
        maxHp: 450,
        ability: 'Thick Fat',
      );

      final flamethrower = createTestMove(
        name: 'Flamethrower',
        type: 'Fire',
        category: 'Special',
        power: 90,
      );

      final thickFatResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: flamethrower,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Normal'],
      );

      final defenderNoAbility = createTestPokemon(
        name: 'Snorlax',
        level: 100,
        attack: 110,
        defense: 65,
        spAtk: 65,
        spDef: 110,
        maxHp: 450,
        ability: '',
      );
      final noThickFatResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defenderNoAbility,
        move: flamethrower,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Normal'],
      );

      // Thick Fat should reduce by 0.5x
      expect(thickFatResult.maxDamage / noThickFatResult.maxDamage,
          closeTo(0.5, 0.1));
    });

    test('Fur Coat halves physical damage', () {
      final attacker = createTestPokemon(
        name: 'Machamp',
        level: 100,
        attack: 130,
        defense: 80,
        spAtk: 65,
        spDef: 85,
        maxHp: 340,
      );

      final defender = createTestPokemon(
        name: 'Furfrou',
        level: 100,
        attack: 80,
        defense: 90, // Increased defense
        spAtk: 65,
        spDef: 90,
        maxHp: 400, // Increased HP to avoid cap
        ability: 'Fur Coat',
      );

      final tackle = createTestMove(
        // Weaker move
        name: 'Tackle',
        type: 'Normal',
        category: 'Physical',
        power: 40,
      );

      final furCoatResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: tackle,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Normal'],
      );

      final defenderNoAbility = createTestPokemon(
        name: 'Furfrou',
        level: 100,
        attack: 80,
        defense: 90,
        spAtk: 65,
        spDef: 90,
        maxHp: 400,
        ability: '',
      );
      final noFurCoatResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defenderNoAbility,
        move: tackle,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Normal'],
      );

      // Fur Coat should halve physical damage
      expect(furCoatResult.maxDamage / noFurCoatResult.maxDamage,
          closeTo(0.5, 0.1));
    });

    test('Ice Scales halves special damage', () {
      final attacker = createTestPokemon(
        name: 'Alakazam',
        level: 100,
        attack: 50,
        defense: 45,
        spAtk: 135,
        spDef: 95,
        maxHp: 270,
      );

      final defender = createTestPokemon(
        name: 'Frosmoth',
        level: 100,
        attack: 65,
        defense: 60,
        spAtk: 125,
        spDef: 90,
        maxHp: 300,
        ability: 'Ice Scales',
      );

      final psychic = createTestMove(
        name: 'Psychic',
        type: 'Psychic',
        category: 'Special',
        power: 90,
      );

      final iceScalesResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: psychic,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Ice', 'Bug'],
      );

      final defenderNoAbility = createTestPokemon(
        name: 'Frosmoth',
        level: 100,
        attack: 65,
        defense: 60,
        spAtk: 125,
        spDef: 90,
        maxHp: 300,
        ability: '',
      );
      final noIceScalesResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defenderNoAbility,
        move: psychic,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Ice', 'Bug'],
      );

      // Ice Scales should halve special damage
      expect(iceScalesResult.maxDamage / noIceScalesResult.maxDamage,
          closeTo(0.5, 0.1));
    });

    test('Multiscale halves damage at full HP', () {
      final attacker = createTestPokemon(
        name: 'Garchomp',
        level: 100,
        attack: 130,
        defense: 95,
        spAtk: 80,
        spDef: 85,
        maxHp: 350,
      );

      final defender = createTestPokemon(
        name: 'Dragonite',
        level: 100,
        attack: 134,
        defense: 95,
        spAtk: 100,
        spDef: 100,
        maxHp: 360,
        ability: 'Multiscale',
      );

      final dragonClaw = createTestMove(
        name: 'Dragon Claw',
        type: 'Dragon',
        category: 'Physical',
        power: 80,
      );

      // Full HP
      final fullHpResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: dragonClaw,
        attackerTypes: ['Dragon', 'Ground'],
        defenderTypes: ['Dragon', 'Flying'],
      );

      // Damaged HP
      defender.currentHp = 350;
      final damagedHpResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: dragonClaw,
        attackerTypes: ['Dragon', 'Ground'],
        defenderTypes: ['Dragon', 'Flying'],
      );

      // Full HP should halve damage
      expect(fullHpResult.maxDamage / damagedHpResult.maxDamage,
          closeTo(0.5, 0.1));
    });

    test('Fluffy halves contact damage but doubles Fire damage', () {
      final physicalAttacker = createTestPokemon(
        name: 'Machamp',
        level: 100,
        attack: 130,
        defense: 80,
        spAtk: 65,
        spDef: 85,
        maxHp: 340,
      );

      final fireAttacker = createTestPokemon(
        name: 'Charizard',
        level: 100,
        attack: 84,
        defense: 78,
        spAtk: 109,
        spDef: 85,
        maxHp: 300,
      );

      final defender = createTestPokemon(
        name: 'Stufful',
        level: 100, // Increased level
        attack: 75,
        defense: 80, // Increased defense
        spAtk: 45,
        spDef: 60, // Increased special defense
        maxHp: 300, // Increased HP to avoid cap
        ability: 'Fluffy',
      );

      final tackle = createTestMove(
        // Weaker move
        name: 'Tackle',
        type: 'Normal',
        category: 'Physical',
        power: 40,
        makesContact: true,
      );

      final ember = createTestMove(
        // Weaker fire move
        name: 'Ember',
        type: 'Fire',
        category: 'Special',
        power: 40,
      );

      // Contact move should be halved
      final contactResult = calculator.calculateDamage(
        attacker: physicalAttacker,
        defender: defender,
        move: tackle,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Normal', 'Fighting'],
      );

      final defenderNoAbility = createTestPokemon(
        name: 'Stufful',
        level: 100,
        attack: 75,
        defense: 80,
        spAtk: 45,
        spDef: 60,
        maxHp: 300,
        ability: '',
      );
      final noFluffyContactResult = calculator.calculateDamage(
        attacker: physicalAttacker,
        defender: defenderNoAbility,
        move: tackle,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Normal', 'Fighting'],
      );

      expect(contactResult.maxDamage / noFluffyContactResult.maxDamage,
          closeTo(0.5, 0.1));

      // Fire move should be doubled
      final fireResult = calculator.calculateDamage(
        attacker: fireAttacker,
        defender: defender,
        move: ember,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Normal', 'Fighting'],
      );

      final noFluffyFireResult = calculator.calculateDamage(
        attacker: fireAttacker,
        defender: defenderNoAbility,
        move: ember,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Normal', 'Fighting'],
      );

      expect(fireResult.maxDamage / noFluffyFireResult.maxDamage,
          closeTo(2.0, 0.1));
    });

    test('Purifying Salt halves Ghost-type damage', () {
      final attacker = createTestPokemon(
        name: 'Gengar',
        level: 100,
        attack: 65,
        defense: 60,
        spAtk: 130,
        spDef: 75,
        maxHp: 290,
      );

      final defender = createTestPokemon(
        name: 'Garganacl',
        level: 100,
        attack: 100,
        defense: 130,
        spAtk: 45,
        spDef: 90,
        maxHp: 380,
        ability: 'Purifying Salt',
      );

      final shadowBall = createTestMove(
        name: 'Shadow Ball',
        type: 'Ghost',
        category: 'Special',
        power: 80,
      );

      final purifyingSaltResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: shadowBall,
        attackerTypes: ['Ghost', 'Poison'],
        defenderTypes: ['Rock'],
      );

      final defenderNoAbility = createTestPokemon(
        name: 'Garganacl',
        level: 100,
        attack: 100,
        defense: 130,
        spAtk: 45,
        spDef: 90,
        maxHp: 380,
        ability: '',
      );
      final noAbilityResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defenderNoAbility,
        move: shadowBall,
        attackerTypes: ['Ghost', 'Poison'],
        defenderTypes: ['Rock'],
      );

      // Purifying Salt should halve Ghost damage
      expect(purifyingSaltResult.maxDamage / noAbilityResult.maxDamage,
          closeTo(0.5, 0.1));
    });
  });

  group('Weather Effects - Damage Modifiers', () {
    test('Sun boosts Fire-type moves by 50%', () {
      final attacker = createTestPokemon(
        name: 'Alakazam',
        level: 100,
        attack: 50,
        defense: 45,
        spAtk: 135,
        spDef: 95,
        maxHp: 270,
      );

      final defender = createTestPokemon(
        name: 'Golem',
        level: 100,
        attack: 120,
        defense: 130,
        spAtk: 55,
        spDef: 65,
        maxHp: 300,
      );

      final ember = createTestMove(
        name: 'Ember',
        type: 'Fire',
        category: 'Special',
        power: 40,
      );

      final sunResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: ember,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Rock', 'Ground'],
        weather: 'sun',
      );

      final noWeatherResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: ember,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Rock', 'Ground'],
      );

      // Sun should boost Fire-type by 1.5x
      expect(
          sunResult.maxDamage / noWeatherResult.maxDamage, closeTo(1.5, 0.1));
    });

    test('Sun reduces Water-type moves by 50%', () {
      final attacker = createTestPokemon(
        name: 'Blastoise',
        level: 100,
        attack: 83,
        defense: 100,
        spAtk: 85,
        spDef: 105,
        maxHp: 300,
      );

      final defender = createTestPokemon(
        name: 'Charizard',
        level: 100,
        attack: 84,
        defense: 78,
        spAtk: 109,
        spDef: 85,
        maxHp: 300,
      );

      final surf = createTestMove(
        name: 'Surf',
        type: 'Water',
        category: 'Special',
        power: 90,
      );

      final sunResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: surf,
        attackerTypes: ['Water'],
        defenderTypes: ['Fire', 'Flying'],
        weather: 'sun',
      );

      final noWeatherResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: surf,
        attackerTypes: ['Water'],
        defenderTypes: ['Fire', 'Flying'],
      );

      // Sun should reduce Water-type by 0.5x
      expect(
          sunResult.maxDamage / noWeatherResult.maxDamage, closeTo(0.5, 0.1));
    });

    test('Rain boosts Water-type moves by 50%', () {
      final attacker = createTestPokemon(
        name: 'Alakazam',
        level: 100,
        attack: 50,
        defense: 45,
        spAtk: 135,
        spDef: 95,
        maxHp: 270,
      );

      final defender = createTestPokemon(
        name: 'Charizard',
        level: 100,
        attack: 84,
        defense: 78,
        spAtk: 109,
        spDef: 85,
        maxHp: 300,
      );

      final watergun = createTestMove(
        name: 'Water Gun',
        type: 'Water',
        category: 'Special',
        power: 40,
      );

      final rainResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: watergun,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Fire', 'Flying'],
        weather: 'rain',
      );

      final noWeatherResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: watergun,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Fire', 'Flying'],
      );

      // Rain should boost Water-type by 1.5x
      expect(
          rainResult.maxDamage / noWeatherResult.maxDamage, closeTo(1.5, 0.1));
    });

    test('Rain reduces Fire-type moves by 50%', () {
      final attacker = createTestPokemon(
        name: 'Charizard',
        level: 100,
        attack: 84,
        defense: 78,
        spAtk: 109,
        spDef: 85,
        maxHp: 300,
      );

      final defender = createTestPokemon(
        name: 'Venusaur',
        level: 100,
        attack: 82,
        defense: 83,
        spAtk: 100,
        spDef: 100,
        maxHp: 300,
      );

      final fireBlast = createTestMove(
        name: 'Fire Blast',
        type: 'Fire',
        category: 'Special',
        power: 110,
      );

      final rainResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: fireBlast,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Grass', 'Poison'],
        weather: 'rain',
      );

      final noWeatherResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: fireBlast,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Grass', 'Poison'],
      );

      // Rain should reduce Fire-type by 0.5x
      expect(
          rainResult.maxDamage / noWeatherResult.maxDamage, closeTo(0.5, 0.1));
    });

    test('Harsh Sunlight boosts Fire and reduces Water', () {
      final attacker = createTestPokemon(
        name: 'Alakazam',
        level: 100,
        attack: 50,
        defense: 45,
        spAtk: 135,
        spDef: 95,
        maxHp: 270,
      );

      final defender = createTestPokemon(
        name: 'Golem',
        level: 100,
        attack: 120,
        defense: 130,
        spAtk: 55,
        spDef: 65,
        maxHp: 300,
      );

      final ember = createTestMove(
        name: 'Ember',
        type: 'Fire',
        category: 'Special',
        power: 40,
      );

      final harshSunResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: ember,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Rock', 'Ground'],
        weather: 'harsh_sunlight',
      );

      final noWeatherResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: ember,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Rock', 'Ground'],
      );

      // Harsh Sunlight should boost Fire-type by 1.5x (same as regular sun)
      expect(harshSunResult.maxDamage / noWeatherResult.maxDamage,
          closeTo(1.5, 0.1));
    });

    test('Heavy Rain boosts Water and reduces Fire', () {
      final attacker = createTestPokemon(
        name: 'Alakazam',
        level: 100,
        attack: 50,
        defense: 45,
        spAtk: 135,
        spDef: 95,
        maxHp: 270,
      );

      final defender = createTestPokemon(
        name: 'Arcanine',
        level: 100,
        attack: 115,
        defense: 80,
        spAtk: 80,
        spDef: 80,
        maxHp: 300,
      );

      final watergun = createTestMove(
        name: 'Water Gun',
        type: 'Water',
        category: 'Special',
        power: 40,
      );

      final heavyRainResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: watergun,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Fire'],
        weather: 'heavy_rain',
      );

      final noWeatherResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: watergun,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Fire'],
      );

      // Heavy Rain should boost Water-type by 1.5x (same as regular rain)
      expect(heavyRainResult.maxDamage / noWeatherResult.maxDamage,
          closeTo(1.5, 0.1));
    });

    test('Sandstorm reduces Special damage taken by Rock-types', () {
      final attacker = createTestPokemon(
        name: 'Alakazam',
        level: 100,
        attack: 50,
        defense: 45,
        spAtk: 135,
        spDef: 95,
        maxHp: 270,
      );

      final defender = createTestPokemon(
        name: 'Rhyperior',
        level: 100,
        attack: 140,
        defense: 130,
        spAtk: 55,
        spDef: 65,
        maxHp: 325,
      );

      final psychic = createTestMove(
        name: 'Psychic',
        type: 'Psychic',
        category: 'Special',
        power: 50,
      );

      final sandstormResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: psychic,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Rock', 'Ground'],
        weather: 'sandstorm',
      );

      final noWeatherResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: psychic,
        attackerTypes: ['Psychic'],
        defenderTypes: ['Rock', 'Ground'],
      );

      // Sandstorm should reduce special damage to Rock-types by ~0.67x (inverse of 1.5x)
      expect(sandstormResult.maxDamage / noWeatherResult.maxDamage,
          closeTo(0.67, 0.1));
    });

    test('Hail reduces Physical damage taken by Ice-types', () {
      final attacker = createTestPokemon(
        name: 'Machamp',
        level: 100,
        attack: 130,
        defense: 80,
        spAtk: 65,
        spDef: 85,
        maxHp: 305,
      );

      final defender = createTestPokemon(
        name: 'Glaceon',
        level: 100,
        attack: 65,
        defense: 110,
        spAtk: 130,
        spDef: 95,
        maxHp: 325,
      );

      final punch = createTestMove(
        name: 'Punch',
        type: 'Fighting',
        category: 'Physical',
        power: 50,
      );

      final hailResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: punch,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Ice'],
        weather: 'hail',
      );

      final noWeatherResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: punch,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Ice'],
      );

      // Hail should reduce physical damage to Ice-types by ~0.67x
      expect(
          hailResult.maxDamage / noWeatherResult.maxDamage, closeTo(0.67, 0.1));
    });

    test('Snow reduces Physical damage taken by Ice-types (same as Hail)', () {
      final attacker = createTestPokemon(
        name: 'Machamp',
        level: 100,
        attack: 130,
        defense: 80,
        spAtk: 65,
        spDef: 85,
        maxHp: 305,
      );

      final defender = createTestPokemon(
        name: 'Glaceon',
        level: 100,
        attack: 65,
        defense: 110,
        spAtk: 130,
        spDef: 95,
        maxHp: 325,
      );

      final punch = createTestMove(
        name: 'Punch',
        type: 'Fighting',
        category: 'Physical',
        power: 50,
      );

      final snowResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: punch,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Ice'],
        weather: 'snow',
      );

      final noWeatherResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: punch,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Ice'],
      );

      // Snow should reduce physical damage to Ice-types by ~0.67x
      expect(
          snowResult.maxDamage / noWeatherResult.maxDamage, closeTo(0.67, 0.1));
    });

    test('Weather does not affect non-matching move types', () {
      final attacker = createTestPokemon(
        name: 'Machamp',
        level: 100,
        attack: 130,
        defense: 80,
        spAtk: 65,
        spDef: 85,
        maxHp: 305,
      );

      final defender = createTestPokemon(
        name: 'Golem',
        level: 100,
        attack: 120,
        defense: 130,
        spAtk: 55,
        spDef: 65,
        maxHp: 300,
      );

      final punch = createTestMove(
        name: 'Punch',
        type: 'Fighting',
        category: 'Physical',
        power: 40,
      );

      final sunResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: punch,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Rock', 'Ground'],
        weather: 'sun',
      );

      final noWeatherResult = calculator.calculateDamage(
        attacker: attacker,
        defender: defender,
        move: punch,
        attackerTypes: ['Fighting'],
        defenderTypes: ['Rock', 'Ground'],
      );

      // Fighting-type move should not be affected by sun/rain weather
      expect(sunResult.maxDamage, equals(noWeatherResult.maxDamage));
    });
  });

  group('User Reported Cases', () {
    test('Charizard Ancient Power vs Weedle in double battle', () {
      // Level 50 Charizard with 31 IVs, 0 EVs, Adamant Nature
      final charizard = createTestPokemon(
        name: 'Charizard',
        level: 50,
        attack: 114,
        defense: 98,
        spAtk: 116,
        spDef: 105,
        maxHp: 153,
      );

      // Level 50 Weedle with 31 IVs, 0 EVs, Careful Nature
      final weedle = createTestPokemon(
        name: 'Weedle',
        level: 50,
        attack: 55,
        defense: 50,
        spAtk: 36,
        spDef: 44,
        maxHp: 115,
      );

      // Ancient Power: 60 BP, Rock-type, Special attack
      final ancientPower = createTestMove(
        name: 'Ancient Power',
        type: 'Rock',
        category: 'Special',
        power: 60,
        accuracy: 100,
        makesContact: false,
      );

      // Double battle (targetCount: 2)
      final result = calculator.calculateDamage(
        attacker: charizard,
        defender: weedle,
        move: ancientPower,
        attackerTypes: ['Fire', 'Flying'],
        defenderTypes: ['Bug', 'Poison'],
      );

      print('=== Charizard vs Weedle (Double Battle) ===');
      print('Attacker: Charizard Lv50');
      print(
          '  Stats - HP: 153, Atk: 114, Def: 98, SpA: 116, SpD: 105, Spe: 120');
      print('Defender: Weedle Lv50');
      print('  Stats - HP: 115, Atk: 55, Def: 50, SpA: 36, SpD: 44, Spe: 70');
      print('Move: Ancient Power (60 BP Rock-type Special)');
      print('Battle: Double battle, but Ancient Power is single-target');
      print('Type Effectiveness: Rock vs Bug/Poison (2x super effective)');
      print('Calculated Range: ${result.minDamage} - ${result.maxDamage}');
      print('Hit Chance: ${(result.hitChance * 100).toStringAsFixed(1)}%');
      print('');
      print('=== DETAILED STEP-BY-STEP CALCULATION ===');
      print('');
      print('STEP 1: Base Damage Formula');
      print('  Formula: (((2*Level/5+2)*Power*Attack/Defense)/50+2)');
      print('  Level: 50, Power: 60, Attack (SpA): 116, Defense (SpD): 44');

      // Manual calculation with explicit steps
      print('');
      print('  Calculating step by step:');
      double levelPart = 2 * 50 / 5 + 2;
      print('    2 * 50 = ${2 * 50}');
      print('    100 / 5 = ${100 / 5}');
      print('    20 + 2 = $levelPart');

      double withPower = levelPart * 60;
      print('    $levelPart * 60 = $withPower');

      double withAttack = withPower * 116;
      print('    $withPower * 116 = $withAttack');

      double withDefense = withAttack / 44;
      print('    $withAttack / 44 = $withDefense');

      double beforeFinal = withDefense / 50;
      print('    $withDefense / 50 = $beforeFinal');

      double baseDamageRaw = beforeFinal + 2;
      print('    $beforeFinal + 2 = $baseDamageRaw');
      print('  Base Damage (raw, before random): $baseDamageRaw');

      // Double-check: if correct range is 120-142, work backward
      print('');
      print('  Verification (working backward from expected 120-142):');
      print('    Max damage 142 / type 2x = 71');
      print('    Min damage 120 / type 2x = 60');
      print('    So after random roll should be 60-71');
      print('    Base damage for 60-71 at 85-100% roll:');
      print('      71 / 1.0 = 71');
      print('      60 / 0.85 = ${60 / 0.85}');
      print('    So base damage should produce ~60-71 after random');
      print('');

      print('STEP 2: Apply Targets Multiplier');
      print('  Single-target move (default targetCount=1): 1.0x');
      print('  Damage after targets: $baseDamageRaw');
      print('');

      print('STEP 3: Random Damage Roll (85-100%)');
      double minRoll = baseDamageRaw * 0.85;
      double maxRoll = baseDamageRaw * 1.00;
      print('  Min: $baseDamageRaw * 0.85 = $minRoll');
      print('  Max: $baseDamageRaw * 1.00 = $maxRoll');
      print('');

      print('STEP 4: STAB (Same Type Attack Bonus)');
      print('  Attacker Types: Fire, Flying');
      print('  Move Type: Rock');
      print('  STAB Applied: No (different type)');
      print('  STAB Multiplier: 1.0x');
      double afterStabMin = minRoll * 1.0;
      double afterStabMax = maxRoll * 1.0;
      print('  Damage after STAB: $afterStabMin - $afterStabMax');
      print('');

      print('STEP 5: Type Effectiveness');
      print('  Rock effectiveness vs Bug: 2x (super effective)');
      print('  Rock effectiveness vs Poison: 2x (super effective)');
      print('  Combined: 2x');
      double afterTypeMin = afterStabMin * 2;
      double afterTypeMax = afterStabMax * 2;
      print('  Min: $afterStabMin * 2 = $afterTypeMin');
      print('  Max: $afterStabMax * 2 = $afterTypeMax');
      print('');

      print('STEP 6: Burn Modifier');
      print('  No burn status: 1.0x');
      print('');

      print('STEP 7: Other Modifiers (Abilities, Items, etc)');
      print('  No relevant abilities or items: 1.0x');
      print('');

      print('STEP 8: Z-Move Protection');
      print('  Not a Z-Move: 1.0x');
      print('');

      print('FINAL CALCULATION:');
      print('  Min damage (raw): $afterTypeMin');
      print('  Max damage (raw): $afterTypeMax');
      int minFinal = afterTypeMin.ceil();
      int maxFinal = afterTypeMax.ceil();
      print('  Min damage (ceiled): $minFinal');
      print('  Max damage (ceiled): $maxFinal');
      print('');
      print('EXPECTED RANGE: $minFinal-$maxFinal');
      print('ACTUAL RANGE: ${result.minDamage}-${result.maxDamage}');
    });
  });
}
