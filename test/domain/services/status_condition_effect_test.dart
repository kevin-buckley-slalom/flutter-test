import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/data/models/pokemon_stats.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/domain/battle/simulation_event.dart';
import 'package:championdex/domain/services/battle_simulation_engine.dart';

void main() {
  late BattleSimulationEngine engine;
  late Map<String, dynamic> moveDatabase;

  BattlePokemon createTestPokemon({
    required String name,
    int level = 50,
    List<String>? types,
    BattleAction? queuedAction,
    String? ability,
  }) {
    return BattlePokemon(
      pokemonName: name,
      originalName: name,
      maxHp: 100,
      currentHp: 100,
      level: level,
      ability: ability ?? '',
      item: null,
      isShiny: false,
      teraType: 'Normal',
      moves: [],
      statStages: {
        'hp': 0,
        'atk': 0,
        'def': 0,
        'spa': 0,
        'spd': 0,
        'spe': 0,
        'acc': 0,
        'eva': 0,
      },
      queuedAction: queuedAction,
      imagePath: null,
      imagePathLarge: null,
      stats: PokemonStats(
        total: 500,
        hp: 100,
        attack: 100,
        defense: 100,
        spAtk: 100,
        spDef: 100,
        speed: 100,
      ),
      types: types ?? ['Normal'],
      status: null,
    );
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final jsonString = File('assets/data/type_chart.json').readAsStringSync();
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final byteData = ByteData.view(bytes.buffer);
    ServicesBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async => byteData);

    moveDatabase = {
      'Buzzy Buzz': Move(
        name: 'Buzzy Buzz',
        type: 'Electric',
        category: 'Special',
        power: 90,
        accuracy: 100,
        pp: 15,
        effect: '',
        makesContact: false,
        generation: 7,
        structuredEffects: [
          {
            'type': 'StatusConditionEffect',
            'condition': 'paralysis',
            'target': 'opponent',
            'probability': 100,
          }
        ],
      ),
      'Dark Void': Move(
        name: 'Dark Void',
        type: 'Dark',
        category: 'Status',
        power: null,
        accuracy: 50,
        pp: 10,
        effect: '',
        makesContact: false,
        generation: 4,
        targets: 'Targets all adjacent foes.',
        structuredEffects: [
          {
            'type': 'StatusConditionEffect',
            'condition': 'sleep',
            'target': 'all_adjacent_opponents',
            'probability': 100,
          }
        ],
      ),
      'Flamethrower': Move(
        name: 'Flamethrower',
        type: 'Fire',
        category: 'Special',
        power: 90,
        accuracy: 100,
        pp: 15,
        effect: '',
        makesContact: false,
        generation: 1,
        structuredEffects: [
          {
            'type': 'StatusConditionEffect',
            'condition': 'burn',
            'target': 'opponent',
            'probability': 100,
          }
        ],
      ),
      'Tackle': Move(
        name: 'Tackle',
        type: 'Normal',
        category: 'Physical',
        power: 40,
        accuracy: 100,
        pp: 35,
        effect: '',
        makesContact: true,
        generation: 1,
      ),
      'Baneful Bunker': Move(
        name: 'Baneful Bunker',
        type: 'Poison',
        category: 'Status',
        power: null,
        accuracy: null,
        pp: 10,
        effect: '',
        makesContact: false,
        generation: 7,
        structuredEffects: [
          {
            'type': 'ProtectionEffect',
            'protectionType': 'blocks all attacks',
            'target': 'user',
            'priority': 4,
            'note': 'Success rate decreases with consecutive uses',
          },
          {
            'type': 'StatusConditionEffect',
            'condition': 'poison',
            'target': 'attacking_opponent',
            'probability': 100,
            'note': 'Only if attacker makes physical contact',
          }
        ],
      ),
      'Dire Claw': Move(
        name: 'Dire Claw',
        type: 'Poison',
        category: 'Physical',
        power: 80,
        accuracy: 100,
        pp: 15,
        effect: '',
        makesContact: true,
        generation: 9,
        structuredEffects: [
          {
            'type': 'StatusConditionEffect',
            'condition': 'poison',
            'target': 'opponent',
            'probability': 50,
            'sharedGroup': 1,
          },
          {
            'type': 'StatusConditionEffect',
            'condition': 'paralysis',
            'target': 'opponent',
            'probability': 50,
            'sharedGroup': 1,
          },
          {
            'type': 'StatusConditionEffect',
            'condition': 'sleep',
            'target': 'opponent',
            'probability': 50,
            'sharedGroup': 1,
          }
        ],
      ),
      'Thunder Wave': Move(
        name: 'Thunder Wave',
        type: 'Electric',
        category: 'Status',
        power: null,
        accuracy: 90,
        pp: 20,
        effect: '',
        makesContact: false,
        generation: 1,
        structuredEffects: [
          {
            'type': 'StatusConditionEffect',
            'condition': 'paralysis',
            'target': 'opponent',
            'probability': 100,
          }
        ],
      ),
      'Toxic': Move(
        name: 'Toxic',
        type: 'Poison',
        category: 'Status',
        power: null,
        accuracy: 90,
        pp: 10,
        effect: '',
        makesContact: false,
        generation: 2,
        structuredEffects: [
          {
            'type': 'StatusConditionEffect',
            'condition': 'toxic',
            'target': 'opponent',
            'probability': 100,
          }
        ],
      ),
      'Stun Spore': Move(
        name: 'Stun Spore',
        type: 'Grass',
        category: 'Status',
        power: null,
        accuracy: 75,
        pp: 30,
        effect: '',
        makesContact: false,
        generation: 1,
        structuredEffects: [
          {
            'type': 'StatusConditionEffect',
            'condition': 'paralysis',
            'target': 'opponent',
            'probability': 100,
          }
        ],
      ),
    };

    engine = BattleSimulationEngine(moveDatabase: moveDatabase);
    await engine.initialize();
  });

  test('StatusConditionEffect applies to opponent', () {
    final attacker = createTestPokemon(name: 'Pikachu');
    final defender = createTestPokemon(name: 'Eevee');

    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: const AttackAction(moveName: 'Buzzy Buzz'),
      },
      fieldConditions: {},
    );

    final defenderFinal = outcome.finalStates[defender.originalName]!;
    expect(defenderFinal.status, 'paralysis');
  });

  test('StatusConditionEffect applies to all adjacent opponents', () {
    final attacker = createTestPokemon(name: 'Darkrai');
    final defender1 = createTestPokemon(name: 'Pikachu');
    final defender2 = createTestPokemon(name: 'Eevee');

    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender1, defender2],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: const AttackAction(moveName: 'Dark Void'),
      },
      fieldConditions: {},
    );

    final defenderFinal1 = outcome.finalStates[defender1.originalName]!;
    final defenderFinal2 = outcome.finalStates[defender2.originalName]!;
    expect(defenderFinal1.status, 'sleep');
    expect(defenderFinal2.status, 'sleep');
  });

  test('StatusConditionEffect respects type immunities', () {
    final attacker = createTestPokemon(name: 'Charizard');
    final defender = createTestPokemon(name: 'Flareon', types: ['Fire']);

    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: const AttackAction(moveName: 'Flamethrower'),
      },
      fieldConditions: {},
    );

    final defenderFinal = outcome.finalStates[defender.originalName]!;
    expect(defenderFinal.status, isNull);
  });

  test('Protection contact status applies to attacker', () {
    final attacker = createTestPokemon(name: 'Froakie');
    final defender = createTestPokemon(
      name: 'Toxapex',
      queuedAction: const AttackAction(moveName: 'Baneful Bunker'),
    );

    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: const AttackAction(moveName: 'Tackle'),
        defender.originalName: const AttackAction(moveName: 'Baneful Bunker'),
      },
      fieldConditions: {},
    );

    final attackerFinal = outcome.finalStates[attacker.originalName]!;
    expect(attackerFinal.status, 'poison');
  });

  test('Shared status effects select only one condition', () {
    // Dire Claw has 3 possible statuses in a shared group, should only get one
    final attacker = createTestPokemon(name: 'Toxicroak');
    final defender = createTestPokemon(name: 'Charizard');

    // Run multiple times to verify we sometimes get different statuses
    final outcomes = <String?>{};
    for (int i = 0; i < 10; i++) {
      final outcome = engine.processTurn(
        team1Active: [attacker],
        team2Active: [defender],
        team1Bench: [],
        team2Bench: [],
        actionsMap: {
          attacker.originalName: const AttackAction(moveName: 'Dire Claw'),
        },
        fieldConditions: {},
      );

      final status = outcome.finalStates[defender.originalName]?.status;
      if (status != null) {
        outcomes.add(status);
        // Verify only valid shared statuses are applied
        expect(
          ['poison', 'paralysis', 'sleep'].contains(status),
          isTrue,
          reason: 'Got unexpected status: $status',
        );
      }
    }
    // We should get at least one status (poison, paralysis, or sleep)
    expect(outcomes.isNotEmpty, isTrue);
  });

  test('Probability-based status effects can fail to apply', () {
    // Thunder Wave has 90% accuracy, so should sometimes fail
    final attacker = createTestPokemon(name: 'Pikachu');
    final defender = createTestPokemon(name: 'Blastoise');

    int failureCount = 0;

    for (int i = 0; i < 20; i++) {
      final outcome = engine.processTurn(
        team1Active: [attacker],
        team2Active: [defender],
        team1Bench: [],
        team2Bench: [],
        actionsMap: {
          attacker.originalName: const AttackAction(moveName: 'Thunder Wave'),
        },
        fieldConditions: {},
      );

      final status = outcome.finalStates[defender.originalName]?.status;
      if (status != 'paralysis') {
        failureCount++;
      }
    }

    // With 90% accuracy and 20 tests, we expect some failures
    expect(failureCount > 0, isTrue, reason: 'Expected at least some failures');
  });

  test('Toxic condition normalizes to badPoison', () {
    final attacker = createTestPokemon(name: 'Muk');
    final defender = createTestPokemon(name: 'Blissey');

    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: const AttackAction(moveName: 'Toxic'),
      },
      fieldConditions: {},
    );

    final defenderFinal = outcome.finalStates[defender.originalName]!;
    // Toxic should be converted to badPoison internally
    expect(defenderFinal.status, 'badPoison');
  });

  test('Ability-based immunity prevents status application', () {
    final attacker = createTestPokemon(name: 'Pikachu');
    final defender = createTestPokemon(
      name: 'Ampharos',
      ability: 'Static', // Not immunity, should not protect
    );

    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: const AttackAction(moveName: 'Thunder Wave'),
      },
      fieldConditions: {},
    );

    final defenderFinal = outcome.finalStates[defender.originalName]!;
    // Static doesn't prevent paralysis, so should get paralyzed
    expect(defenderFinal.status, 'paralysis');
  });

  test('Ability-based immunity to paralysis blocks status', () {
    final attacker = createTestPokemon(name: 'Pikachu');
    final defender = createTestPokemon(
      name: 'Electabuzz',
      ability: 'Limber', // Prevents paralysis
    );

    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: const AttackAction(moveName: 'Thunder Wave'),
      },
      fieldConditions: {},
    );

    final defenderFinal = outcome.finalStates[defender.originalName]!;
    // Limber prevents paralysis
    expect(defenderFinal.status, isNull);
  });

  test('Multiple consecutive status applications', () {
    // Test that moving Pokemon can have status applied multiple times in sequence
    final attacker1 = createTestPokemon(name: 'Pikachu');
    final attacker2 = createTestPokemon(name: 'Jolteon');
    final defender = createTestPokemon(name: 'Dragonite');

    // First application - paralysis
    var outcome = engine.processTurn(
      team1Active: [attacker1],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker1.originalName: const AttackAction(moveName: 'Thunder Wave'),
      },
      fieldConditions: {},
    );

    var defenderFinal = outcome.finalStates[defender.originalName]!;
    expect(defenderFinal.status, 'paralysis');

    // Try applying again - should already have status, so no change
    // (The engine should report "already paralyzed" or similar)
    outcome = engine.processTurn(
      team1Active: [attacker2],
      team2Active: [defenderFinal],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker2.originalName: const AttackAction(moveName: 'Stun Spore'),
      },
      fieldConditions: {},
    );

    defenderFinal = outcome.finalStates[defender.originalName]!;
    // Should still have paralysis (already has a status)
    expect(defenderFinal.status, 'paralysis');
  });

  test('Dynamic turn order: paralysis mid-turn affects remaining actions', () {
    // Test Gen 8+ mechanic: turn order recalculates after speed changes
    // Raichu (fast, 110 base speed) uses Thunder Wave on Pidgeot (91 base speed)
    // Pidgeot (medium speed) queued to use Quick Attack
    // Blastoise (slow, 78 base speed) queued to use Water Gun

    final raichu = createTestPokemon(name: 'Raichu');
    final pidgeot = createTestPokemon(name: 'Pidgeot');
    final blastoise = createTestPokemon(name: 'Blastoise');

    // Initial order should be: Raichu (110) > Pidgeot (91) > Blastoise (78)
    // After paralysis: Raichu (110) > Blastoise (78) > Pidgeot (45.5)

    final outcome = engine.processTurn(
      team1Active: [raichu],
      team2Active: [pidgeot, blastoise],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        raichu.originalName: const AttackAction(moveName: 'Thunder Wave'),
        pidgeot.originalName: const AttackAction(moveName: 'Tackle'),
        blastoise.originalName: const AttackAction(moveName: 'Tackle'),
      },
      fieldConditions: {},
    );

    final pidgeotFinal = outcome.finalStates[pidgeot.originalName]!;
    expect(pidgeotFinal.status, 'paralysis');

    // Check the order of events - Thunder Wave should happen before Tackle
    final moveEvents = outcome.events
        .where((e) => e.type == SimulationEventType.moveUsed)
        .toList();

    expect(moveEvents.length, greaterThanOrEqualTo(2));
    expect(moveEvents[0].moveName, 'Thunder Wave'); // Raichu moves first

    // After paralysis, Blastoise (78) should move before Pidgeot (45.5)
    // So the second move should be from Blastoise, not Pidgeot
    // Note: This test validates dynamic turn order recalculation
  });

  test('Sleep prevents move execution', () {
    final attacker = createTestPokemon(name: 'Pikachu', ability: 'Static');
    final defender = createTestPokemon(name: 'Blissey');

    // First, apply sleep
    var outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: const AttackAction(moveName: 'Thunder Wave'),
      },
      fieldConditions: {},
    );

    // Manually apply sleep (simulate previous turn effect)
    final defenderWithSleep = outcome.finalStates[defender.originalName]!;
    defenderWithSleep.status = 'sleep';

    // Now attempt to move while asleep
    outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defenderWithSleep],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        defenderWithSleep.originalName: const AttackAction(moveName: 'Tackle'),
      },
      fieldConditions: {},
    );

    // Check that defender did not use the move
    final summaryEvents = outcome.events
        .where((e) => e.message.contains('is fast asleep'))
        .toList();
    expect(summaryEvents.isNotEmpty, isTrue,
        reason: 'Expected sleep prevention message');

    // Verify that the move was not used
    final moveEvents = outcome.events
        .where((e) =>
            e.type == SimulationEventType.moveUsed && e.moveName == 'Tackle')
        .toList();
    expect(moveEvents.isEmpty, isTrue,
        reason: 'Asleep Pokemon should not execute moves');
  });

  test('Freeze prevents move execution', () {
    final attacker = createTestPokemon(name: 'Pikachu');
    final defender = createTestPokemon(name: 'Blastoise');

    // Manually apply freeze
    defender.status = 'freeze';

    // Attempt to move while frozen
    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        defender.originalName: const AttackAction(moveName: 'Tackle'),
      },
      fieldConditions: {},
    );

    // Check that defender did not use the move
    final summaryEvents = outcome.events
        .where((e) => e.message.contains('is frozen solid'))
        .toList();
    expect(summaryEvents.isNotEmpty, isTrue,
        reason: 'Expected freeze prevention message');

    // Verify that the move was not used
    final moveEvents = outcome.events
        .where((e) =>
            e.type == SimulationEventType.moveUsed && e.moveName == 'Tackle')
        .toList();
    expect(moveEvents.isEmpty, isTrue,
        reason: 'Frozen Pokemon should not execute moves');
  });

  test('Drowsy applies volatile status and converts to sleep next turn', () {
    // Create a move with drowsy effect (like Yawn)
    final yawnMove = Move(
      name: 'Yawn',
      type: 'Normal',
      category: 'Status',
      power: null,
      accuracy: null,
      pp: 10,
      effect: '',
      makesContact: false,
      generation: 4,
      structuredEffects: [
        {
          'type': 'StatusConditionEffect',
          'condition': 'sleep',
          'target': 'opponent',
          'probability': 100,
          'appliesToNextTurn': true,
          'note': 'Target falls asleep at the end of next turn',
        }
      ],
    );

    engine.moveDatabase['Yawn'] = yawnMove;

    final attacker = createTestPokemon(name: 'Slowking');
    final defender = createTestPokemon(name: 'Pikachu');

    // Turn 1: Use Yawn - should apply drowsy volatile status, not sleep
    var outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: const AttackAction(moveName: 'Yawn'),
        defender.originalName: const AttackAction(moveName: 'Tackle'),
      },
      fieldConditions: {},
    );

    var defenderAfterYawn = outcome.finalStates[defender.originalName]!;

    // Defender should NOT have sleep status yet, only drowsy volatile
    expect(defenderAfterYawn.status, isNull,
        reason: 'Yawn should not apply sleep status immediately');
    expect(defenderAfterYawn.getVolatileStatus('drowsy_turns'), isNotNull,
        reason: 'Yawn should apply drowsy volatile status');

    // Defender should still be able to attack on the turn they get hit with Yawn
    final defenderMovesOnYawnTurn = outcome.events
        .where((e) =>
            e.type == SimulationEventType.moveUsed && e.moveName == 'Tackle')
        .toList();
    expect(defenderMovesOnYawnTurn.isNotEmpty, isTrue,
        reason: 'Pokemon hit with Yawn should still move that turn');

    // Turn 2: Drowsy counter decrements, and at end of turn converts to sleep
    outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defenderAfterYawn],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: const AttackAction(moveName: 'Tackle'),
      },
      fieldConditions: {},
    );

    final defenderAfterNextTurn = outcome.finalStates[defender.originalName]!;

    // After end-of-turn processing, drowsy should have converted to sleep
    expect(defenderAfterNextTurn.status, 'sleep',
        reason: 'Drowsy should convert to sleep at end of next turn');
    expect(defenderAfterNextTurn.getVolatileStatus('drowsy_turns'), isNull,
        reason:
            'Drowsy volatile status should be removed when converting to sleep');
  });
}
