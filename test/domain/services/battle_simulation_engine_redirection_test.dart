import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:championdex/domain/services/battle_simulation_engine.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/data/models/pokemon_stats.dart';

void main() {
  late BattleSimulationEngine engine;
  late Map<String, dynamic> moveDatabase;

  // Helper to create a test Pokémon
  BattlePokemon createTestPokemon({
    required String name,
    required int level,
    int attack = 100,
    int defense = 100,
    int spAtk = 100,
    int spDef = 100,
    int maxHp = 100,
    int currentHp = 100,
    String ability = 'Intimidate',
    String? item,
    List<String> types = const ['Normal'],
    Map<String, int>? statStages,
    BattleAction? queuedAction,
  }) {
    return BattlePokemon(
      pokemonName: name,
      originalName: name,
      maxHp: maxHp,
      currentHp: currentHp,
      level: level,
      ability: ability,
      item: item,
      isShiny: false,
      teraType: 'Normal',
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
      queuedAction: queuedAction,
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
      types: types,
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
    List<Map<String, dynamic>>? structuredEffects,
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
      structuredEffects: structuredEffects,
    );
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Load type chart for damage calculator
    final jsonString = File('assets/data/type_chart.json').readAsStringSync();
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final byteData = ByteData.view(bytes.buffer);
    ServicesBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async => byteData);

    // Initialize move database
    moveDatabase = {
      'Tackle': createTestMove(
        name: 'Tackle',
        type: 'Normal',
        category: 'Physical',
        power: 40,
      ),
      'Water Gun': createTestMove(
        name: 'Water Gun',
        type: 'Water',
        category: 'Special',
        power: 40,
      ),
      'Thunderbolt': createTestMove(
        name: 'Thunderbolt',
        type: 'Electric',
        category: 'Special',
        power: 90,
      ),
      'Follow Me': createTestMove(
        name: 'Follow Me',
        type: 'Normal',
        category: 'Status',
        power: null,
        priority: 2,
      ),
      'Rage Powder': createTestMove(
        name: 'Rage Powder',
        type: 'Bug',
        category: 'Status',
        power: null,
        priority: 2,
      ),
      'Snipe Shot': createTestMove(
        name: 'Snipe Shot',
        type: 'Water',
        category: 'Special',
        power: 80,
        structuredEffects: [
          {
            'type': 'AttackRedirectionBypassEffect',
            'ignoresMoveRedirection': true,
            'ignoredAbilities': true,
            'increasedCriticalRate': true,
            'criticalRatio': 0.125,
          }
        ],
      ),
    };

    engine = BattleSimulationEngine(moveDatabase: moveDatabase);
    await engine.initialize();
  });

  group('Follow Me Redirection Tests', () {
    test('Follow Me successfully redirects opponent attack to redirector', () {
      // Setup: Team 1 has Pikachu, Team 2 has Clefable (Follow Me) and Charizard
      final pikachuAction = AttackAction(
        moveName: 'Tackle',
        targetPokemonName: 'Charizard',
      );
      final clefableAction = AttackAction(
        moveName: 'Follow Me',
        targetPokemonName: null,
      );

      final pikachu = createTestPokemon(
        name: 'Pikachu',
        level: 50,
        queuedAction: pikachuAction,
      );
      final clefable = createTestPokemon(
        name: 'Clefable',
        level: 50,
        queuedAction: clefableAction,
      );
      final charizard = createTestPokemon(name: 'Charizard', level: 50);

      final result = engine.processTurn(
        team1Active: [pikachu],
        team2Active: [clefable, charizard],
        team1Bench: [],
        team2Bench: [],
        actionsMap: {
          'Pikachu': pikachuAction,
          'Clefable': clefableAction,
        },
        fieldConditions: {},
      );

      // Verify Follow Me was used first (higher priority)
      expect(
        result.events.any((e) => e.message.contains('Clefable used Follow Me')),
        isTrue,
        reason: 'Clefable should use Follow Me',
      );

      // Verify redirection message appears
      expect(
        result.events
            .any((e) => e.message.contains('became the center of attention')),
        isTrue,
        reason: 'Redirection activation message should appear',
      );

      // Verify Pikachu's attack was redirected to Clefable
      expect(
        result.events
            .any((e) => e.message.contains('Clefable drew the attack')),
        isTrue,
        reason: 'Attack should be redirected to Clefable',
      );

      // Verify Clefable took damage, not Charizard
      final clefableFinal = result.finalStates['Clefable']!;
      final charizardFinal = result.finalStates['Charizard']!;
      expect(clefableFinal.currentHp, lessThan(clefable.maxHp),
          reason: 'Clefable should take damage');
      expect(charizardFinal.currentHp, equals(charizard.maxHp),
          reason: 'Charizard should not take damage');
    });

    test('Follow Me does not redirect teammate attacks', () {
      // Setup: Both pokemon on same team
      final clefableAction = AttackAction(
        moveName: 'Follow Me',
        targetPokemonName: null,
      );
      final blisseyAction = AttackAction(
        moveName: 'Tackle',
        targetPokemonName: 'Clefable',
      );

      final clefable = createTestPokemon(
        name: 'Clefable',
        level: 50,
        queuedAction: clefableAction,
      );
      final blissey = createTestPokemon(
        name: 'Blissey',
        level: 50,
        queuedAction: blisseyAction,
      );
      final garchomp = createTestPokemon(name: 'Garchomp', level: 50);

      final result = engine.processTurn(
        team1Active: [clefable, blissey],
        team2Active: [garchomp],
        team1Bench: [],
        team2Bench: [],
        actionsMap: {
          'Clefable': clefableAction,
          'Blissey': blisseyAction,
        },
        fieldConditions: {},
      );

      // Verify attack was not redirected (no "drew the attack" message)
      expect(
        result.events.any((e) => e.message.contains('drew the attack')),
        isFalse,
        reason: 'Teammate attacks should not be redirected',
      );
    });
  });

  group('Snipe Shot Bypass Tests', () {
    test('Snipe Shot bypasses Follow Me redirection', () {
      final clefableAction = AttackAction(
        moveName: 'Follow Me',
        targetPokemonName: null,
      );
      final inteleonAction = AttackAction(
        moveName: 'Snipe Shot',
        targetPokemonName: 'Charizard',
      );

      final inteleon = createTestPokemon(
        name: 'Inteleon',
        level: 50,
        types: ['Water'],
        queuedAction: inteleonAction,
      );
      final clefable = createTestPokemon(
        name: 'Clefable',
        level: 50,
        queuedAction: clefableAction,
      );
      final charizard = createTestPokemon(name: 'Charizard', level: 50);

      final result = engine.processTurn(
        team1Active: [inteleon],
        team2Active: [clefable, charizard],
        team1Bench: [],
        team2Bench: [],
        actionsMap: {
          'Inteleon': inteleonAction,
          'Clefable': clefableAction,
        },
        fieldConditions: {},
      );

      // Verify Follow Me was used
      expect(
        result.events.any((e) =>
            e.message.contains('Clefable') &&
            e.message.contains('center of attention')),
        isTrue,
        reason: 'Follow Me should activate',
      );

      // Verify attack was NOT redirected (no "drew the attack" message)
      expect(
        result.events.any((e) => e.message.contains('drew the attack')),
        isFalse,
        reason: 'Snipe Shot should bypass Follow Me',
      );

      // Verify Charizard took damage, not Clefable
      final clefableFinal = result.finalStates['Clefable']!;
      final charizardFinal = result.finalStates['Charizard']!;
      expect(clefableFinal.currentHp, equals(clefable.maxHp),
          reason: 'Clefable should not take damage');
      expect(charizardFinal.currentHp, lessThan(charizard.maxHp),
          reason: 'Charizard should take damage');
    });

    test('Snipe Shot bypasses Storm Drain ability redirection', () {
      final inteleonAction = AttackAction(
        moveName: 'Snipe Shot',
        targetPokemonName: 'Charizard',
      );

      final inteleon = createTestPokemon(
        name: 'Inteleon',
        level: 50,
        types: ['Water'],
        queuedAction: inteleonAction,
      );
      final gastrodon = createTestPokemon(
        name: 'Gastrodon',
        level: 50,
        ability: 'Storm Drain',
        types: ['Water', 'Ground'],
      );
      final charizard = createTestPokemon(name: 'Charizard', level: 50);

      final result = engine.processTurn(
        team1Active: [inteleon],
        team2Active: [gastrodon, charizard],
        team1Bench: [],
        team2Bench: [],
        actionsMap: {
          'Inteleon': inteleonAction,
        },
        fieldConditions: {},
      );

      // Verify Storm Drain did NOT redirect
      expect(
        result.events.any((e) =>
            e.message.contains('Storm Drain') &&
            e.message.contains('drew the attack')),
        isFalse,
        reason: 'Snipe Shot should bypass Storm Drain',
      );

      // Verify Charizard took damage
      final charizardFinal = result.finalStates['Charizard']!;
      expect(charizardFinal.currentHp, lessThan(charizard.maxHp),
          reason: 'Charizard should take damage');
    });
  });

  group('Ability-Based Redirection Tests', () {
    test('Storm Drain redirects Water-type moves', () {
      final blastoiseAction = AttackAction(
        moveName: 'Water Gun',
        targetPokemonName: 'Charizard',
      );

      final blastoise = createTestPokemon(
        name: 'Blastoise',
        level: 50,
        types: ['Water'],
        queuedAction: blastoiseAction,
      );
      final gastrodon = createTestPokemon(
        name: 'Gastrodon',
        level: 50,
        ability: 'Storm Drain',
        types: ['Water', 'Ground'],
      );
      final charizard = createTestPokemon(name: 'Charizard', level: 50);

      final result = engine.processTurn(
        team1Active: [blastoise],
        team2Active: [gastrodon, charizard],
        team1Bench: [],
        team2Bench: [],
        actionsMap: {
          'Blastoise': blastoiseAction,
        },
        fieldConditions: {},
      );

      // Verify Storm Drain redirected the attack
      expect(
        result.events.any((e) =>
            e.message.contains('Storm Drain') &&
            e.message.contains('drew the attack')),
        isTrue,
        reason: 'Storm Drain should redirect Water-type move',
      );

      // Verify Gastrodon took the hit
      final gastrodonFinal = result.finalStates['Gastrodon']!;
      expect(gastrodonFinal.currentHp, lessThan(gastrodon.maxHp),
          reason: 'Gastrodon should take damage');
    });

    test('Lightning Rod redirects Electric-type moves', () {
      final pikachuAction = AttackAction(
        moveName: 'Thunderbolt',
        targetPokemonName: 'Gyarados',
      );

      final pikachu = createTestPokemon(
        name: 'Pikachu',
        level: 50,
        types: ['Electric'],
        queuedAction: pikachuAction,
      );
      final raichu = createTestPokemon(
        name: 'Raichu',
        level: 50,
        ability: 'Lightning Rod',
        types: ['Electric'],
      );
      final gyarados = createTestPokemon(
        name: 'Gyarados',
        level: 50,
        types: ['Water', 'Flying'],
      );

      final result = engine.processTurn(
        team1Active: [pikachu],
        team2Active: [raichu, gyarados],
        team1Bench: [],
        team2Bench: [],
        actionsMap: {
          'Pikachu': pikachuAction,
        },
        fieldConditions: {},
      );

      // Verify Lightning Rod redirected the attack
      expect(
        result.events.any((e) =>
            e.message.contains('Lightning Rod') &&
            e.message.contains('drew the attack')),
        isTrue,
        reason: 'Lightning Rod should redirect Electric-type move',
      );

      // Verify Gyarados did NOT take damage
      final gyaradosFinal = result.finalStates['Gyarados']!;
      expect(gyaradosFinal.currentHp, equals(gyarados.maxHp),
          reason: 'Gyarados should not take damage');
    });
  });

  group('Auto-Retargeting Tests', () {
    test('Attack retargets to another opponent if original target is KO\'d',
        () {
      // Setup: Garchomp KOs Charizard, then Pikachu's attack auto-retargets to Dragonite
      final garchompAction = AttackAction(
        moveName: 'Tackle',
        targetPokemonName: 'Charizard',
      );
      final pikachuAction = AttackAction(
        moveName: 'Tackle',
        targetPokemonName: 'Charizard',
      );

      final garchomp = createTestPokemon(
        name: 'Garchomp',
        level: 50,
        attack: 200,
        types: ['Dragon', 'Ground'],
        queuedAction: garchompAction,
      );
      final pikachu = createTestPokemon(
        name: 'Pikachu',
        level: 50,
        types: ['Electric'],
        queuedAction: pikachuAction,
      );
      final charizard = createTestPokemon(
        name: 'Charizard',
        level: 50,
        currentHp: 1, // Will be KO'd
      );
      final dragonite = createTestPokemon(
        name: 'Dragonite',
        level: 50,
        types: ['Dragon', 'Flying'],
      );

      final result = engine.processTurn(
        team1Active: [garchomp, pikachu],
        team2Active: [charizard, dragonite],
        team1Bench: [],
        team2Bench: [],
        actionsMap: {
          'Garchomp': garchompAction,
          'Pikachu': pikachuAction,
        },
        fieldConditions: {},
      );

      // Verify Charizard was KO'd
      final charizardFinal = result.finalStates['Charizard']!;
      expect(charizardFinal.currentHp, equals(0),
          reason: 'Charizard should be KO\'d');

      // Verify retargeting message
      expect(
        result.events.any((e) =>
            e.message.contains('redirected to') &&
            e.message.contains('Dragonite')),
        isTrue,
        reason: 'Attack should be auto-retargeted to Dragonite',
      );

      // Verify Dragonite took damage
      final dragoniteFinal = result.finalStates['Dragonite']!;
      expect(dragoniteFinal.currentHp, lessThan(dragonite.maxHp),
          reason: 'Dragonite should take damage from retargeted attack');
    });
  });
}
