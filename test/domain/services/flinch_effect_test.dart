import 'package:flutter_test/flutter_test.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/domain/battle/simulation_event.dart';
import 'package:championdex/domain/services/battle_simulation_engine.dart';

// Mock move repository - load moves from assets manually
Future<Map<String, dynamic>> loadMoveDatabase() async {
  // For now, return a minimal database with test moves
  final moveDb = <String, dynamic>{};

  // Create Air Slash with flinch
  moveDb['Air Slash'] = Move(
    name: 'Air Slash',
    type: 'Flying',
    power: 75,
    accuracy: 95,
    priority: 0,
    targets: 'single',
    effect: 'Chance to make the target flinch.',
    effectChanceRaw: 30,
    category: 'Special',
    makesContact: false,
    pp: 15,
    generation: 4,
    structuredEffects: [
      {
        'type': 'FlinchEffect',
        'probability': 30,
        'target': 'normal',
      }
    ],
  );

  // Create Fake Out with guaranteed flinch
  moveDb['Fake Out'] = Move(
    name: 'Fake Out',
    type: 'Normal',
    power: 40,
    accuracy: 100,
    priority: 3,
    targets: 'single',
    effect: 'High priority. Prevents the target from moving.',
    effectChanceRaw: 100,
    category: 'Physical',
    makesContact: true,
    pp: 10,
    generation: 3,
    structuredEffects: [
      {
        'type': 'FlinchEffect',
        'probability': 100,
        'target': 'normal',
      }
    ],
  );

  // Create Upper Hand
  moveDb['Upper Hand'] = Move(
    name: 'Upper Hand',
    type: 'Fighting',
    power: 65,
    accuracy: 100,
    priority: 3,
    targets: 'single',
    effect: 'High priority. Flinches if target used a priority move.',
    effectChanceRaw: 100,
    category: 'Physical',
    makesContact: true,
    pp: 15,
    generation: 8,
    structuredEffects: [
      {
        'type': 'FlinchEffect',
        'probability': 100,
        'target': 'normal',
        'note': 'target chose priority move',
      }
    ],
  );

  // Create Quick Attack
  moveDb['Quick Attack'] = Move(
    name: 'Quick Attack',
    type: 'Normal',
    power: 40,
    accuracy: 100,
    priority: 1,
    targets: 'single',
    effect: 'High priority.',
    effectChanceRaw: null,
    category: 'Physical',
    makesContact: true,
    pp: 30,
    generation: 1,
    structuredEffects: [],
  );

  // Create Thunderbolt
  moveDb['Thunderbolt'] = Move(
    name: 'Thunderbolt',
    type: 'Electric',
    power: 90,
    accuracy: 100,
    priority: 0,
    targets: 'single',
    effect: 'Has a 10% chance to paralyze.',
    effectChanceRaw: 10,
    category: 'Special',
    makesContact: false,
    pp: 15,
    generation: 1,
    structuredEffects: [],
  );

  // Create Flare Blitz
  moveDb['Flare Blitz'] = Move(
    name: 'Flare Blitz',
    type: 'Fire',
    power: 120,
    accuracy: 100,
    priority: 0,
    targets: 'single',
    effect: 'Has a 10% chance to burn.',
    effectChanceRaw: 10,
    category: 'Physical',
    makesContact: true,
    pp: 15,
    generation: 4,
    structuredEffects: [],
  );

  // Create Hydro Pump
  moveDb['Hydro Pump'] = Move(
    name: 'Hydro Pump',
    type: 'Water',
    power: 110,
    accuracy: 80,
    priority: 0,
    targets: 'single',
    effect: 'No additional effect.',
    effectChanceRaw: null,
    category: 'Special',
    makesContact: false,
    pp: 5,
    generation: 1,
    structuredEffects: [],
  );

  return moveDb;
}

void main() {
  group('FlinchEffect Battle Simulation Tests', () {
    late BattleSimulationEngine engine;
    late Map<String, dynamic> moveDatabase;
    late BattlePokemon pikachu;
    late BattlePokemon charizard;
    late BattlePokemon blastoise;

    setUpAll(() async {
      moveDatabase = await loadMoveDatabase();
    });

    setUp(() {
      engine = BattleSimulationEngine(moveDatabase: moveDatabase);

      // Create test pokemon
      pikachu = BattlePokemon(
        pokemonName: 'Pikachu',
        originalName: 'Pikachu',
        maxHp: 100,
        currentHp: 100,
        level: 50,
        ability: 'Static',
        item: null,
        isShiny: false,
        teraType: 'Electric',
        moves: ['Thunderbolt', 'Quick Attack'],
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
        queuedAction: null,
        imagePath: 'assets/pokemon/pikachu',
        imagePathLarge: 'assets/pokemon_large/pikachu',
        stats: null,
        types: ['Electric'],
        status: null,
      );

      charizard = BattlePokemon(
        pokemonName: 'Charizard',
        originalName: 'Charizard',
        maxHp: 120,
        currentHp: 120,
        level: 50,
        ability: 'Blaze',
        item: null,
        isShiny: false,
        teraType: 'Fire',
        moves: ['Flare Blitz', 'Air Slash'],
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
        queuedAction: null,
        imagePath: 'assets/pokemon/charizard',
        imagePathLarge: 'assets/pokemon_large/charizard',
        stats: null,
        types: ['Fire', 'Flying'],
        status: null,
      );

      blastoise = BattlePokemon(
        pokemonName: 'Blastoise',
        originalName: 'Blastoise',
        maxHp: 120,
        currentHp: 120,
        level: 50,
        ability: 'Inner Focus',
        item: null,
        isShiny: false,
        teraType: 'Water',
        moves: ['Aqua Jet', 'Hydro Pump'],
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
        queuedAction: null,
        imagePath: 'assets/pokemon/blastoise',
        imagePathLarge: 'assets/pokemon_large/blastoise',
        stats: null,
        types: ['Water'],
        status: null,
      );
    });

    test('Flinch status prevents pokemon from moving', () async {
      // Setup: Charizard uses Air Slash (has 30% flinch chance)
      // Pikachu should flinch and be unable to move
      await engine.initialize();

      // Set flinch on Pikachu manually to simulate it being flinched previous turn
      pikachu.volatileStatus['flinch'] = true;

      // Create a simple attack action for Charizard
      const fieldConditions = {
        'terrain': null,
        'weather': null,
        'rooms': [],
        'singleSideEffects': {'team1': [], 'team2': []},
        'otherEffects': [],
      };

      final actions = {
        'Charizard':
            AttackAction(moveName: 'Air Slash', targetPokemonName: 'Pikachu'),
        'Pikachu': AttackAction(
            moveName: 'Thunderbolt', targetPokemonName: 'Charizard'),
      };

      final outcome = engine.processTurn(
        team1Active: [pikachu],
        team2Active: [charizard],
        team1Bench: [],
        team2Bench: [],
        actionsMap: actions,
        fieldConditions: fieldConditions,
      );

      // Check that there's a flinch message for Pikachu
      final flinchEvent = outcome.events.firstWhere(
        (e) =>
            e.message.contains('flinched') &&
            e.affectedPokemonName == 'Pikachu',
        orElse: () => SimulationEvent(
          id: '',
          message: 'NO_EVENT',
          type: SimulationEventType.summary,
        ),
      );

      expect(flinchEvent.message, isNotEmpty,
          reason: 'Flinched Pikachu should produce a flinch message');
      expect(flinchEvent.message, isNot('NO_EVENT'));

      // Check that Pikachu didn't use its move
      final pikachuMove = outcome.events.firstWhere(
        (e) => e.message.contains('Pikachu used'),
        orElse: () => SimulationEvent(
          id: '',
          message: 'NO_MOVE',
          type: SimulationEventType.summary,
        ),
      );

      expect(pikachuMove.message, 'NO_MOVE',
          reason: 'Flinched Pikachu should not have used a move');
    });

    test('Flinch status is cleared at end of turn', () async {
      await engine.initialize();

      // Set flinch on Pikachu
      pikachu.volatileStatus['flinch'] = true;

      const fieldConditions = {
        'terrain': null,
        'weather': null,
        'rooms': [],
        'singleSideEffects': {'team1': [], 'team2': []},
        'otherEffects': [],
      };

      final actions = {
        'Pikachu': AttackAction(
            moveName: 'Thunderbolt', targetPokemonName: 'Charizard'),
        'Charizard':
            AttackAction(moveName: 'Flare Blitz', targetPokemonName: 'Pikachu'),
      };

      final outcome = engine.processTurn(
        team1Active: [pikachu],
        team2Active: [charizard],
        team1Bench: [],
        team2Bench: [],
        actionsMap: actions,
        fieldConditions: fieldConditions,
      );

      // Get the final state of Pikachu after turn
      final finalPikachu = outcome.finalStates['Pikachu'];

      // Flinch should be cleared (set to false) at end of turn
      expect(finalPikachu?.volatileStatus['flinch'], isFalse,
          reason: 'Flinch status should be cleared at end of turn');
    });

    test('Fake Out guarantees flinch on target', () async {
      await engine.initialize();

      const fieldConditions = {
        'terrain': null,
        'weather': null,
        'rooms': [],
        'singleSideEffects': {'team1': [], 'team2': []},
        'otherEffects': [],
      };

      // Reset HP
      charizard.currentHp = 120;
      pikachu.currentHp = 100;
      pikachu.volatileStatus.clear();
      charizard.volatileStatus.clear();

      // Charizard uses Fake Out on Pikachu (priority +3, so moves first)
      final actions = {
        'Charizard':
            AttackAction(moveName: 'Fake Out', targetPokemonName: 'Pikachu'),
        'Pikachu': AttackAction(
            moveName: 'Quick Attack', targetPokemonName: 'Charizard'),
      };

      final outcome = engine.processTurn(
        team1Active: [pikachu],
        team2Active: [charizard],
        team1Bench: [],
        team2Bench: [],
        actionsMap: actions,
        fieldConditions: fieldConditions,
      );

      // Verify flinch block message appears (Pikachu should be prevented from moving)
      final flinchMessage = outcome.events.any((e) =>
          e.message.contains('flinched and cannot move') &&
          e.affectedPokemonName == 'Pikachu');

      expect(flinchMessage, isTrue,
          reason: 'Pikachu should flinch and be unable to move');

      // Verify Pikachu didn't use Quick Attack
      final pikachuAttacked = outcome.events
          .any((e) => e.message.contains('Pikachu used Quick Attack'));

      expect(pikachuAttacked, isFalse,
          reason: 'Pikachu should not attack while flinched');
    });

    test('Inner Focus ability prevents flinch', () async {
      await engine.initialize();

      // Create Blastoise with Inner Focus ability
      final blastoiseInnerFocus = BattlePokemon(
        pokemonName: 'Blastoise-IF',
        originalName: 'Blastoise-IF',
        maxHp: 120,
        currentHp: 120,
        level: 50,
        ability: 'Inner Focus',
        item: null,
        isShiny: false,
        teraType: 'Water',
        moves: ['Aqua Jet', 'Hydro Pump'],
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
        queuedAction: null,
        imagePath: 'assets/pokemon/blastoise',
        imagePathLarge: 'assets/pokemon_large/blastoise',
        stats: null,
        types: ['Water'],
        status: null,
      );

      const fieldConditions = {
        'terrain': null,
        'weather': null,
        'rooms': [],
        'singleSideEffects': {'team1': [], 'team2': []},
        'otherEffects': [],
      };

      // Run multiple simulations
      int flinchCount = 0;
      const simulations = 50;

      for (int i = 0; i < simulations; i++) {
        charizard.currentHp = 120;
        blastoiseInnerFocus.currentHp = 120;
        blastoiseInnerFocus.volatileStatus.clear();

        final actions = {
          'Charizard': AttackAction(
              moveName: 'Air Slash', targetPokemonName: 'Blastoise-IF'),
          'Blastoise-IF': AttackAction(
              moveName: 'Hydro Pump', targetPokemonName: 'Charizard'),
        };

        final outcome = engine.processTurn(
          team1Active: [blastoiseInnerFocus],
          team2Active: [charizard],
          team1Bench: [],
          team2Bench: [],
          actionsMap: actions,
          fieldConditions: fieldConditions,
        );

        // Check if Blastoise was flinched (shouldn't happen with Inner Focus)
        if (outcome.events.any((e) =>
            e.message.contains('flinched') &&
            e.affectedPokemonName == 'Blastoise-IF')) {
          flinchCount++;
        }

        blastoiseInnerFocus.volatileStatus.clear();
      }

      expect(flinchCount, equals(0),
          reason: 'Inner Focus should prevent all flinches');
    });

    test('Flinch cannot be applied multiple times in same turn', () async {
      await engine.initialize();

      // Manually set flinch on Pikachu
      pikachu.volatileStatus['flinch'] = true;

      const fieldConditions = {
        'terrain': null,
        'weather': null,
        'rooms': [],
        'singleSideEffects': {'team1': [], 'team2': []},
        'otherEffects': [],
      };

      final actions = {
        'Charizard':
            AttackAction(moveName: 'Air Slash', targetPokemonName: 'Pikachu'),
        'Pikachu': AttackAction(
            moveName: 'Quick Attack', targetPokemonName: 'Charizard'),
      };

      final outcome = engine.processTurn(
        team1Active: [pikachu],
        team2Active: [charizard],
        team1Bench: [],
        team2Bench: [],
        actionsMap: actions,
        fieldConditions: fieldConditions,
      );

      // Count flinch messages for Pikachu
      final flinchCount = outcome.events
          .where((e) =>
              e.message.contains('flinched') &&
              e.affectedPokemonName == 'Pikachu')
          .length;

      // Should only have one "cannot move" message due to existing flinch
      expect(flinchCount, equals(1),
          reason: 'Should not apply multiple flinches in same turn');
    });

    test('Multiple pokemon can be flinched in doubles battle', () async {
      await engine.initialize();

      final pikachu2 = BattlePokemon(
        pokemonName: 'Pikachu-2',
        originalName: 'Pikachu-2',
        maxHp: 100,
        currentHp: 100,
        level: 50,
        ability: 'Static',
        item: null,
        isShiny: false,
        teraType: 'Electric',
        moves: ['Thunderbolt'],
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
        queuedAction: null,
        imagePath: 'assets/pokemon/pikachu',
        imagePathLarge: 'assets/pokemon_large/pikachu',
        stats: null,
        types: ['Electric'],
        status: null,
      );

      // Manually flinch both opponents
      pikachu.volatileStatus['flinch'] = true;
      pikachu2.volatileStatus['flinch'] = true;

      const fieldConditions = {
        'terrain': null,
        'weather': null,
        'rooms': [],
        'singleSideEffects': {'team1': [], 'team2': []},
        'otherEffects': [],
      };

      final actions = {
        'Charizard':
            AttackAction(moveName: 'Air Slash', targetPokemonName: 'Pikachu'),
        'Blastoise': AttackAction(
            moveName: 'Hydro Pump', targetPokemonName: 'Pikachu-2'),
        'Pikachu': AttackAction(
            moveName: 'Quick Attack', targetPokemonName: 'Charizard'),
        'Pikachu-2': AttackAction(
            moveName: 'Thunderbolt', targetPokemonName: 'Blastoise'),
      };

      final outcome = engine.processTurn(
        team1Active: [pikachu, pikachu2],
        team2Active: [charizard, blastoise],
        team1Bench: [],
        team2Bench: [],
        actionsMap: actions,
        fieldConditions: fieldConditions,
      );

      // Check that both pokemon couldn't move
      final pikachuCouldntMove = outcome.events.any((e) =>
          e.message.contains('flinched') && e.affectedPokemonName == 'Pikachu');
      final pikachu2CouldntMove = outcome.events.any((e) =>
          e.message.contains('flinched') &&
          e.affectedPokemonName == 'Pikachu-2');

      expect(pikachuCouldntMove, isTrue,
          reason: 'Pikachu should not move due to flinch');
      expect(pikachu2CouldntMove, isTrue,
          reason: 'Pikachu-2 should not move due to flinch');
    });
  });

  group('Flinch Move Analysis Tests', () {
    late Map<String, dynamic> moveDatabase;

    setUpAll(() async {
      moveDatabase = await loadMoveDatabase();
    });

    test('Air Slash has FlinchEffect in structured effects', () {
      final airSlash = moveDatabase['Air Slash'] as Move?;
      expect(airSlash, isNotNull,
          reason: 'Air Slash should exist in move database');

      final hasFlinchEffect = airSlash?.structuredEffects
              ?.any((effect) => effect['type'] == 'FlinchEffect') ??
          false;
      expect(hasFlinchEffect, isTrue,
          reason: 'Air Slash should have FlinchEffect');
    });

    test('Fake Out move has correct properties', () {
      final fakeOut = moveDatabase['Fake Out'] as Move?;
      expect(fakeOut, isNotNull, reason: 'Fake Out should exist');

      // Check priority
      expect(fakeOut?.priority, equals(3),
          reason: 'Fake Out should have priority +3');

      // Check flinch effect
      final flinchEffect = fakeOut?.structuredEffects
          ?.firstWhere((e) => e['type'] == 'FlinchEffect', orElse: () => {});
      expect(flinchEffect?.isNotEmpty, isTrue,
          reason: 'Fake Out should have FlinchEffect');
      expect((flinchEffect?['probability'] ?? 0), equals(100),
          reason: 'Fake Out flinch should be 100%');
    });

    test('Upper Hand move has priority', () {
      final upperHand = moveDatabase['Upper Hand'] as Move?;
      expect(upperHand, isNotNull, reason: 'Upper Hand should exist');

      // Check priority
      expect(upperHand?.priority, equals(3),
          reason: 'Upper Hand should have priority +3');

      // Check flinch effect
      final hasFlinch = upperHand?.structuredEffects
              ?.any((e) => e['type'] == 'FlinchEffect') ??
          false;
      expect(hasFlinch, isTrue, reason: 'Upper Hand should have FlinchEffect');
    });
  });
}
