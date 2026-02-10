import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/data/models/pokemon_stats.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/domain/services/battle_simulation_engine.dart';

void main() {
  late BattleSimulationEngine engine;
  late Map<String, dynamic> moveDatabase;

  BattlePokemon createTestPokemon({
    required String name,
    int level = 50,
    List<String>? types,
  }) {
    return BattlePokemon(
      pokemonName: name,
      originalName: name,
      maxHp: 100,
      currentHp: 100,
      level: level,
      ability: '',
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
      'Growl': Move(
        name: 'Growl',
        type: 'Normal',
        category: 'Status',
        power: null,
        accuracy: 100,
        pp: 40,
        effect: '',
        makesContact: false,
        generation: 1,
        structuredEffects: [
          {
            'type': 'StatChangeEffect',
            'stats': {'attack': -1},
            'target': 'opponent',
            'probability': 100,
          }
        ],
      ),
      'Swords Dance': Move(
        name: 'Swords Dance',
        type: 'Normal',
        category: 'Status',
        power: null,
        accuracy: null,
        pp: 20,
        effect: '',
        makesContact: false,
        generation: 1,
        structuredEffects: [
          {
            'type': 'StatChangeEffect',
            'stats': {'attack': 2},
            'target': 'user',
            'probability': 100,
          }
        ],
      ),
      'Aromatic Mist': Move(
        name: 'Aromatic Mist',
        type: 'Fairy',
        category: 'Status',
        power: null,
        accuracy: null,
        pp: 20,
        effect: '',
        makesContact: false,
        generation: 6,
        structuredEffects: [
          {
            'type': 'StatChangeEffect',
            'stats': {'spDef': 1},
            'target': 'ally',
            'probability': 100,
          }
        ],
      ),
      'Breaking Swipe': Move(
        name: 'Breaking Swipe',
        type: 'Dragon',
        category: 'Physical',
        power: 60,
        accuracy: 100,
        pp: 15,
        effect: '',
        makesContact: true,
        generation: 8,
        structuredEffects: [
          {
            'type': 'StatChangeEffect',
            'stats': {'attack': -1},
            'target': 'allOpponents',
            'probability': 100,
          }
        ],
      ),
      'Sand Attack': Move.fromJson({
        'name': 'Sand Attack',
        'type': 'Ground',
        'category': 'Status',
        'power': null,
        'accuracy': 100,
        'pp': 15,
        'effect': '',
        'effect_chance': null,
        'makes_contact': false,
        'generation': 1,
        'structuredEffects': [
          {
            'type': 'StatChangeEffect',
            'target': 'opponent',
            'accuracy': -1,
            'probability': 100,
          }
        ],
      }),
    };

    engine = BattleSimulationEngine(moveDatabase: moveDatabase);
    await engine.initialize();
  });

  Map<String, dynamic> buildFieldConditions() => {
        'trickRoom': false,
      };

  test('StatChangeEffect applies to user', () {
    final attacker = createTestPokemon(name: 'Scizor');
    final defender = createTestPokemon(name: 'Pikachu');

    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: AttackAction(
          moveName: 'Swords Dance',
          targetPokemonName: attacker.originalName,
        ),
      },
      fieldConditions: buildFieldConditions(),
    );

    final attackerFinal = outcome.finalStates[attacker.originalName]!;
    expect(attackerFinal.statStages['atk'], 2);
  });

  test('StatChangeEffect applies to opponent', () {
    final attacker = createTestPokemon(name: 'Eevee');
    final defender = createTestPokemon(name: 'Bulbasaur');

    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: AttackAction(
          moveName: 'Growl',
          targetPokemonName: defender.originalName,
        ),
      },
      fieldConditions: buildFieldConditions(),
    );

    final defenderFinal = outcome.finalStates[defender.originalName]!;
    expect(defenderFinal.statStages['atk'], -1);
  });

  test('StatChangeEffect applies to ally', () {
    final attacker = createTestPokemon(name: 'Clefairy');
    final ally = createTestPokemon(name: 'Clefable');
    final defender = createTestPokemon(name: 'Charmander');

    final outcome = engine.processTurn(
      team1Active: [attacker, ally],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: AttackAction(
          moveName: 'Aromatic Mist',
          targetPokemonName: ally.originalName,
        ),
      },
      fieldConditions: buildFieldConditions(),
    );

    final allyFinal = outcome.finalStates[ally.originalName]!;
    expect(allyFinal.statStages['spd'], 1);
  });

  test('StatChangeEffect applies to all opponents', () {
    final attacker = createTestPokemon(name: 'Haxorus');
    final defender1 = createTestPokemon(name: 'Skarmory');
    final defender2 = createTestPokemon(name: 'Garchomp');

    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender1, defender2],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: AttackAction(
          moveName: 'Breaking Swipe',
          targetPokemonName: defender1.originalName,
        ),
      },
      fieldConditions: buildFieldConditions(),
    );

    final defenderFinal1 = outcome.finalStates[defender1.originalName]!;
    final defenderFinal2 = outcome.finalStates[defender2.originalName]!;
    expect(defenderFinal1.statStages['atk'], -1);
    expect(defenderFinal2.statStages['atk'], -1);
  });

  test('StatChangeEffect normalizes direct stat keys', () {
    final attacker = createTestPokemon(name: 'Sandslash');
    final defender = createTestPokemon(name: 'Butterfree');

    final outcome = engine.processTurn(
      team1Active: [attacker],
      team2Active: [defender],
      team1Bench: [],
      team2Bench: [],
      actionsMap: {
        attacker.originalName: AttackAction(
          moveName: 'Sand Attack',
          targetPokemonName: defender.originalName,
        ),
      },
      fieldConditions: buildFieldConditions(),
    );

    final defenderFinal = outcome.finalStates[defender.originalName]!;
    expect(defenderFinal.statStages['acc'], -1);
  });
}
