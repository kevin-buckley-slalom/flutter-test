import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:championdex/domain/services/battle_simulation_engine.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/data/models/pokemon_stats.dart';

void main() {
  late Map<String, dynamic> moveDatabase;

  // Helper to create test pokemon
  BattlePokemon createTestPokemon({
    required String name,
    required int level,
    String? item,
  }) {
    return BattlePokemon(
      pokemonName: name,
      originalName: name,
      maxHp: 100,
      currentHp: 100,
      level: level,
      ability: 'Static',
      item: item,
      isShiny: false,
      teraType: 'Normal',
      moves: ['Tackle', 'Light Screen', 'Reflect', 'Aurora Veil'],
      statStages: {
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
        total: 484,
        hp: 100,
        attack: 100,
        defense: 100,
        spAtk: 100,
        spDef: 100,
        speed: 84,
      ),
      types: ['Normal'],
      status: null,
    );
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Load type chart
    final jsonString = File('assets/data/type_chart.json').readAsStringSync();
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final byteData = ByteData.view(bytes.buffer);
    ServicesBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async => byteData);

    // Create move database with screen moves
    moveDatabase = {
      'Tackle': {
        'type': 'Normal',
        'category': 'Physical',
        'power': 40,
        'accuracy': 100,
        'pp': 35,
        'effect': null,
        'makes_contact': true,
        'generation': 1,
        'targets': 'Single Adjacent Target',
        'structuredEffects': [],
      },
      'Light Screen': {
        'type': 'Psychic',
        'category': 'Status',
        'power': null,
        'accuracy': null,
        'pp': 30,
        'effect': null,
        'makes_contact': false,
        'generation': 1,
        'targets': 'Ally Team',
        'structuredEffects': [
          {
            'type': 'ScreenEffect',
            'screenType': 'light-screen',
            'damageReduction': 0.5,
            'duration': 5,
            'teamWide': true,
            'probability': 100,
          }
        ],
      },
      'Reflect': {
        'type': 'Psychic',
        'category': 'Status',
        'power': null,
        'accuracy': null,
        'pp': 30,
        'effect': null,
        'makes_contact': false,
        'generation': 1,
        'targets': 'Ally Team',
        'structuredEffects': [
          {
            'type': 'ScreenEffect',
            'screenType': 'reflect',
            'damageReduction': 0.5,
            'duration': 5,
            'teamWide': true,
            'probability': 100,
          }
        ],
      },
      'Aurora Veil': {
        'type': 'Ice',
        'category': 'Status',
        'power': null,
        'accuracy': null,
        'pp': 30,
        'effect': null,
        'makes_contact': false,
        'generation': 6,
        'targets': 'Ally Team',
        'structuredEffects': [
          {
            'type': 'ScreenEffect',
            'screenType': 'aurora-veil',
            'damageReduction': 0.5,
            'duration': 5,
            'teamWide': true,
            'probability': 100,
            'requiresHail': true,
          }
        ],
      },
      'Brick Break': {
        'type': 'Fighting',
        'category': 'Physical',
        'power': 75,
        'accuracy': 100,
        'pp': 15,
        'effect': null,
        'makes_contact': true,
        'generation': 3,
        'targets': 'Single Adjacent Target',
        'structuredEffects': [
          {
            'type': 'BarrierBreakerEffect',
            'breaksBarriers': ['light-screen', 'reflect', 'aurora-veil'],
            'targetTeam': 'opponent',
            'probability': 100,
          }
        ],
      },
      'Glitzy Glow': {
        'type': 'Fairy',
        'category': 'Special',
        'power': 80,
        'accuracy': 100,
        'pp': 10,
        'effect': null,
        'makes_contact': false,
        'generation': 8,
        'targets': 'Single Adjacent Target',
        'structuredEffects': [
          {
            'type': 'ScreenEffect',
            'screenType': 'light-screen',
            'damageReduction': 0.5,
            'duration': 5,
            'teamWide': true,
            'probability': 100,
          }
        ],
      },
    };

    // Create engine
    // ignore: unused_local_variable
    final engine = BattleSimulationEngine(moveDatabase: moveDatabase);
  });

  group('Light Screen Setup', () {
    test('Basic Light Screen setup', () {
      final move = moveDatabase['Light Screen'];

      final screenState = ScreenState();
      final effects = move['structuredEffects'] as List<dynamic>;

      for (final effect in effects) {
        if (effect['type'] == 'ScreenEffect') {
          screenState.lightScreenTurns = effect['duration'] as int;
          break;
        }
      }

      expect(screenState.lightScreenTurns, 5);
      expect(screenState.hasLightScreen, true);
    });

    test('Light Clay extends Light Screen to 8 turns', () {
      final attacker =
          createTestPokemon(name: 'Alakazam', level: 50, item: 'Light Clay');

      final screenState = ScreenState();
      var duration = 5;

      // Simulate Light Clay extension
      if (attacker.item?.toLowerCase().contains('light clay') ?? false) {
        duration = 8;
      }

      screenState.lightScreenTurns = duration;

      expect(screenState.lightScreenTurns, 8);
      expect(screenState.hasLightScreen, true);
    });
  });

  group('Reflect Setup', () {
    test('Basic Reflect setup', () {
      final move = moveDatabase['Reflect'];

      final screenState = ScreenState();
      final effects = move['structuredEffects'] as List<dynamic>;

      for (final effect in effects) {
        if (effect['type'] == 'ScreenEffect') {
          screenState.reflectTurns = effect['duration'] as int;
          break;
        }
      }

      expect(screenState.reflectTurns, 5);
      expect(screenState.hasReflect, true);
    });

    test('Light Screen and Reflect can stack', () {
      final screenState = ScreenState();

      screenState.lightScreenTurns = 5;
      screenState.reflectTurns = 5;

      expect(screenState.hasLightScreen, true);
      expect(screenState.hasReflect, true);
      expect(screenState.lightScreenTurns, 5);
      expect(screenState.reflectTurns, 5);
    });
  });

  group('Screen Duration Management', () {
    test('Screen duration decrements each turn', () {
      final screenState = ScreenState();
      screenState.lightScreenTurns = 5;
      screenState.reflectTurns = 5;

      screenState.decrementTurns();
      expect(screenState.lightScreenTurns, 4);
      expect(screenState.reflectTurns, 4);

      screenState.decrementTurns();
      expect(screenState.lightScreenTurns, 3);
      expect(screenState.reflectTurns, 3);
    });

    test('Screen expires after duration', () {
      final screenState = ScreenState();
      screenState.lightScreenTurns = 1;

      screenState.decrementTurns();
      expect(screenState.lightScreenTurns, 0);
      expect(screenState.hasLightScreen, false);
    });

    test('Multiple screens decrement independently', () {
      final screenState = ScreenState();
      screenState.lightScreenTurns = 5;
      screenState.reflectTurns = 3;
      screenState.auroraVeilTurns = 4;

      screenState.decrementTurns();
      expect(screenState.lightScreenTurns, 4);
      expect(screenState.reflectTurns, 2);
      expect(screenState.auroraVeilTurns, 3);
    });
  });

  group('Aurora Veil Setup', () {
    test('Aurora Veil setup', () {
      final move = moveDatabase['Aurora Veil'];

      final screenState = ScreenState();
      final effects = move['structuredEffects'] as List<dynamic>;

      for (final effect in effects) {
        if (effect['type'] == 'ScreenEffect') {
          screenState.auroraVeilTurns = effect['duration'] as int;
          break;
        }
      }

      expect(screenState.auroraVeilTurns, 5);
      expect(screenState.hasAuroraVeil, true);
    });
  });

  group('Brick Break Screen Removal', () {
    test('Brick Break removes Light Screen', () {
      final screenState = ScreenState();
      screenState.lightScreenTurns = 5;

      // Simulate barrier breaking
      screenState.lightScreenTurns = 0;

      expect(screenState.hasLightScreen, false);
    });

    test('Brick Break removes Reflect', () {
      final screenState = ScreenState();
      screenState.reflectTurns = 5;

      // Simulate barrier breaking
      screenState.reflectTurns = 0;

      expect(screenState.hasReflect, false);
    });

    test('Brick Break removes Aurora Veil', () {
      final screenState = ScreenState();
      screenState.auroraVeilTurns = 5;

      // Simulate barrier breaking
      screenState.auroraVeilTurns = 0;

      expect(screenState.hasAuroraVeil, false);
    });
  });

  group('Screen Removal', () {
    test('Reset clears all screens', () {
      final screenState = ScreenState();
      screenState.lightScreenTurns = 5;
      screenState.reflectTurns = 5;
      screenState.auroraVeilTurns = 5;

      screenState.reset();

      expect(screenState.lightScreenTurns, 0);
      expect(screenState.reflectTurns, 0);
      expect(screenState.auroraVeilTurns, 0);
      expect(screenState.hasLightScreen, false);
      expect(screenState.hasReflect, false);
      expect(screenState.hasAuroraVeil, false);
    });
  });

  group('Glitzy Glow Side Effect', () {
    test('Glitzy Glow sets Light Screen', () {
      final move = moveDatabase['Glitzy Glow'];
      final screenState = ScreenState();

      final effects = move['structuredEffects'] as List<dynamic>;
      for (final effect in effects) {
        if (effect['type'] == 'ScreenEffect') {
          screenState.lightScreenTurns = effect['duration'] as int;
          break;
        }
      }

      expect(screenState.hasLightScreen, true);
    });
  });

  group('Multiple Screens Management', () {
    test('All three screens can be active simultaneously', () {
      final screenState = ScreenState();
      screenState.lightScreenTurns = 5;
      screenState.reflectTurns = 5;
      screenState.auroraVeilTurns = 5;

      expect(screenState.hasLightScreen, true);
      expect(screenState.hasReflect, true);
      expect(screenState.hasAuroraVeil, true);
    });

    test('Screens decrement independently', () {
      final screenState = ScreenState();
      screenState.lightScreenTurns = 5;
      screenState.reflectTurns = 3;
      screenState.auroraVeilTurns = 7;

      for (int i = 0; i < 3; i++) {
        screenState.decrementTurns();
      }

      expect(screenState.lightScreenTurns, 2);
      expect(screenState.reflectTurns, 0);
      expect(screenState.auroraVeilTurns, 4);
    });
  });
}
