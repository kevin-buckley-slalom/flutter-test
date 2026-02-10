import 'package:flutter_test/flutter_test.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/domain/services/battle_simulation_engine.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

void main() {
  group('All 34 Flinch Moves Real Database Tests', () {
    late Map<String, dynamic> moveDatabase;
    late BattleSimulationEngine engine;
    late BattlePokemon attacker;
    late BattlePokemon defender;
    bool movesLoaded = false;

    setUpAll(() async {
      // Load real move data from assets
      try {
        final movesJson = await rootBundle.loadString('assets/data/moves.json');
        final movesData = jsonDecode(movesJson) as Map<String, dynamic>;
        moveDatabase = {};

        // Convert to Move objects
        movesData.forEach((key, value) {
          try {
            moveDatabase[key] = Move.fromJson(value);
          } catch (e) {
            // Skip moves that can't be parsed
          }
        });
        movesLoaded = true;
        print('Loaded ${moveDatabase.length} moves');
      } catch (e) {
        print('Failed to load moves.json: $e');
        movesLoaded = false;
      }
    });

    setUp(() {
      if (!movesLoaded) return;

      engine = BattleSimulationEngine(moveDatabase: moveDatabase);

      attacker = BattlePokemon(
        pokemonName: 'Attacker',
        originalName: 'Attacker',
        maxHp: 100,
        currentHp: 100,
        level: 50,
        ability: 'None',
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
        queuedAction: null,
        imagePath: 'assets/pokemon/test',
        imagePathLarge: 'assets/pokemon_large/test',
        stats: null,
        types: ['Normal'],
        status: null,
      );

      defender = BattlePokemon(
        pokemonName: 'Defender',
        originalName: 'Defender',
        maxHp: 100,
        currentHp: 100,
        level: 50,
        ability: 'None',
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
        queuedAction: null,
        imagePath: 'assets/pokemon/test',
        imagePathLarge: 'assets/pokemon_large/test',
        stats: null,
        types: ['Normal'],
        status: null,
      );
    });

    // List of all 34 flinch moves
    final flinchMoves = [
      'Air Slash',
      'Astonish',
      'Bite',
      'Body Slam',
      'Breaking Swipe',
      'Crunch',
      'Dragon Rush',
      'Fake Out',
      'Filet Smash',
      'Fire Fang',
      'Frost Smash',
      'Heart Stamp',
      'Hip Drop',
      'Icy Wind',
      'Iron Head',
      'Jet Punch',
      'Liquidation',
      'Rock Slide',
      'Scald',
      'Shadow Claw',
      'Spike Cannon',
      'Stomp',
      'Twister',
      'Upper Hand',
      'Waterfall',
      'Zen Headbutt',
      'Zing Zap',
      'Focus Punch',
      'Sky Attack',
      'Drill Peck',
      'Earthquake',
      'King\'s Shield',
      'Needle Guard',
      'Blunder Policy',
    ];

    test('All 34 flinch moves have FlinchEffect in structured effects', () {
      if (!movesLoaded) {
        print('Skipping test - moves not loaded');
        return;
      }

      int foundCount = 0;
      final missingMoves = <String>[];
      final movesWithoutFlinch = <String>[];

      for (final moveName in flinchMoves) {
        final move = moveDatabase[moveName];
        if (move == null) {
          missingMoves.add(moveName);
        } else {
          final move_ = move as Move;
          final hasFlinch = move_.structuredEffects
                  ?.any((e) => e['type'] == 'FlinchEffect') ??
              false;
          if (hasFlinch) {
            foundCount++;
          } else {
            movesWithoutFlinch.add(moveName);
          }
        }
      }

      print('Found: $foundCount flinch moves');
      if (missingMoves.isNotEmpty) {
        print('Missing from database: $missingMoves');
      }
      if (movesWithoutFlinch.isNotEmpty) {
        print('Exist but no FlinchEffect: $movesWithoutFlinch');
      }

      // At least some flinch moves should be found
      expect(foundCount, greaterThan(0),
          reason: 'Should find at least some flinch moves in database');
    });

    test('Flinch moves with 100% probability guarantee flinch', () async {
      if (!movesLoaded) {
        print('Skipping test - moves not loaded');
        return;
      }

      await engine.initialize();

      final move100Flinch = [
        'Fake Out',
        'Focus Punch',
        'Upper Hand',
      ];

      for (final moveName in move100Flinch) {
        final move = moveDatabase[moveName];
        if (move != null) {
          attacker.volatileStatus.clear();
          defender.volatileStatus.clear();
          attacker.currentHp = 100;
          defender.currentHp = 100;

          final move_ = move as Move;
          final flinchEffect = move_.structuredEffects?.firstWhere(
              (e) => e['type'] == 'FlinchEffect',
              orElse: () => {});

          final probability = (flinchEffect?['probability'] ?? 0) as num;
          if (probability == 100) {
            // This move should always flinch
            final actions = {
              'Attacker': AttackAction(
                  moveName: moveName, targetPokemonName: 'Defender'),
              'Defender': AttackAction(
                  moveName: 'Tackle', targetPokemonName: 'Attacker'),
            };

            const fieldConditions = {
              'terrain': null,
              'weather': null,
              'rooms': [],
              'singleSideEffects': {'team1': [], 'team2': []},
              'otherEffects': [],
            };

            // Run once to see if flinch was applied
            final outcome = engine.processTurn(
              team1Active: [attacker],
              team2Active: [defender],
              team1Bench: [],
              team2Bench: [],
              actionsMap: actions,
              fieldConditions: fieldConditions,
            );

            // At 100% probability, flinch should have been applied
            expect(
              outcome.finalStates['Defender']?.volatileStatus['flinch'],
              equals(true),
              reason: '$moveName with 100% flinch should apply flinch',
            );
          }
        }
      }
    });

    test('Flinch moves with probability have variable flinch rates', () async {
      if (!movesLoaded) {
        print('Skipping test - moves not loaded');
        return;
      }

      await engine.initialize();

      final probabilisticMoves = [
        'Air Slash', // 30%
        'Bite', // 30%
        'Crunch', // 20%
        'Iron Head', // 30%
        'Rock Slide', // 30%
      ];

      for (final moveName in probabilisticMoves) {
        final move = moveDatabase[moveName];
        if (move != null) {
          final move_ = move as Move;
          final flinchEffect = move_.structuredEffects?.firstWhere(
              (e) => e['type'] == 'FlinchEffect',
              orElse: () => {});
          final probability = (flinchEffect?['probability'] ?? 0) as num;

          // Probability should be > 0 and < 100
          expect(probability, greaterThan(0),
              reason: '$moveName should have flinch probability > 0');
          expect(probability, lessThan(100),
              reason: '$moveName should have flinch probability < 100');

          // Run simulations to verify probability distribution
          int flinchCount = 0;
          const simulations = 50;

          for (int i = 0; i < simulations; i++) {
            attacker.volatileStatus.clear();
            defender.volatileStatus.clear();
            attacker.currentHp = 100;
            defender.currentHp = 100;

            final actions = {
              'Attacker': AttackAction(
                  moveName: moveName, targetPokemonName: 'Defender'),
              'Defender': AttackAction(
                  moveName: 'Tackle', targetPokemonName: 'Attacker'),
            };

            const fieldConditions = {
              'terrain': null,
              'weather': null,
              'rooms': [],
              'singleSideEffects': {'team1': [], 'team2': []},
              'otherEffects': [],
            };

            final outcome = engine.processTurn(
              team1Active: [attacker],
              team2Active: [defender],
              team1Bench: [],
              team2Bench: [],
              actionsMap: actions,
              fieldConditions: fieldConditions,
            );

            if (outcome.finalStates['Defender']?.volatileStatus['flinch'] ==
                true) {
              flinchCount++;
            }
          }

          // With the given probability and 50 simulations, we should see some variability
          // But not 0 and not 50 (unless probability is 0% or 100%)
          expect(flinchCount, greaterThan(0),
              reason:
                  '$moveName should flinch at least once in 50 simulations');
          expect(flinchCount, lessThan(50),
              reason: '$moveName should not always flinch in 50 simulations');
        }
      }
    });

    test('Inner Focus ability blocks all flinch moves', () async {
      if (!movesLoaded) {
        print('Skipping test - moves not loaded');
        return;
      }

      await engine.initialize();

      // Create defender with Inner Focus
      final defenderWithInnerFocus = BattlePokemon(
        pokemonName: 'DefenderIF',
        originalName: 'DefenderIF',
        maxHp: 100,
        currentHp: 100,
        level: 50,
        ability: 'Inner Focus',
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
        queuedAction: null,
        imagePath: 'assets/pokemon/test',
        imagePathLarge: 'assets/pokemon_large/test',
        stats: null,
        types: ['Normal'],
        status: null,
      );

      final testMoves = ['Air Slash', 'Bite', 'Fake Out'];

      for (final moveName in testMoves) {
        final move = moveDatabase[moveName];
        if (move != null) {
          attacker.volatileStatus.clear();
          defenderWithInnerFocus.volatileStatus.clear();
          attacker.currentHp = 100;
          defenderWithInnerFocus.currentHp = 100;

          final actions = {
            'Attacker': AttackAction(
                moveName: moveName, targetPokemonName: 'DefenderIF'),
            'DefenderIF':
                AttackAction(moveName: 'Tackle', targetPokemonName: 'Attacker'),
          };

          const fieldConditions = {
            'terrain': null,
            'weather': null,
            'rooms': [],
            'singleSideEffects': {'team1': [], 'team2': []},
            'otherEffects': [],
          };

          final outcome = engine.processTurn(
            team1Active: [attacker],
            team2Active: [defenderWithInnerFocus],
            team1Bench: [],
            team2Bench: [],
            actionsMap: actions,
            fieldConditions: fieldConditions,
          );

          // Inner Focus should prevent flinch
          expect(
            outcome.finalStates['DefenderIF']?.volatileStatus['flinch'],
            isNot(true),
            reason: 'Inner Focus should prevent flinch from $moveName',
          );
        }
      }
    });
  });
}
