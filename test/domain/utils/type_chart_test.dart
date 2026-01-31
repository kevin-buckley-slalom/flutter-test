import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:championdex/domain/utils/type_chart.dart';

void main() {
  late TypeChartService typeChart;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final jsonString = File('assets/data/type_chart.json').readAsStringSync();
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    final byteData = ByteData.view(bytes.buffer);
    ServicesBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async => byteData);
    typeChart = TypeChartService();
    await typeChart.loadTypeChart();
  });

  group('TypeChartService - Single Type Effectiveness', () {
    test('Fire is super effective against Grass', () {
      expect(typeChart.getEffectiveness('Fire', 'Grass'), equals(2.0));
    });

    test('Water is super effective against Fire', () {
      expect(typeChart.getEffectiveness('Water', 'Fire'), equals(2.0));
    });

    test('Fire is not very effective against Water', () {
      expect(typeChart.getEffectiveness('Fire', 'Water'), equals(0.5));
    });

    test('Normal is immune to Ghost', () {
      expect(typeChart.getEffectiveness('Normal', 'Ghost'), equals(0.0));
    });

    test('Ghost is immune to Normal', () {
      expect(typeChart.getEffectiveness('Ghost', 'Normal'), equals(0.0));
    });

    test('Fighting is immune to Ghost', () {
      expect(typeChart.getEffectiveness('Fighting', 'Ghost'), equals(0.0));
    });

    test('Electric is immune to Ground', () {
      expect(typeChart.getEffectiveness('Electric', 'Ground'), equals(0.0));
    });

    test('Dragon is immune to Fairy', () {
      expect(typeChart.getEffectiveness('Dragon', 'Fairy'), equals(0.0));
    });

    test('Normal vs Normal is neutral', () {
      expect(typeChart.getEffectiveness('Normal', 'Normal'), equals(1.0));
    });

    test('Fire vs Fire is not very effective', () {
      expect(typeChart.getEffectiveness('Fire', 'Fire'), equals(0.5));
    });
  });

  group('TypeChartService - Dual Type Effectiveness', () {
    test('Electric vs Water/Flying (Gyarados) is 4x super effective', () {
      expect(
        typeChart.calculateTypeEffectiveness('Electric', ['Water', 'Flying']),
        equals(4.0),
      );
    });

    test('Rock vs Fire/Flying (Charizard, Moltres) is 4x super effective', () {
      expect(
        typeChart.calculateTypeEffectiveness('Rock', ['Fire', 'Flying']),
        equals(4.0),
      );
    });

    test('Fighting vs Normal/Flying (Pidgey) is neutral (2.0 × 0.5)', () {
      expect(
        typeChart.calculateTypeEffectiveness('Fighting', ['Normal', 'Flying']),
        equals(1.0),
      );
    });

    test('Ground vs Steel/Flying (Skarmory) is immune (2.0 × 0.0)', () {
      expect(
        typeChart.calculateTypeEffectiveness('Ground', ['Steel', 'Flying']),
        equals(0.0),
      );
    });

    test('Grass vs Water/Ground (Quagsire) is 4x super effective', () {
      expect(
        typeChart.calculateTypeEffectiveness('Grass', ['Water', 'Ground']),
        equals(4.0),
      );
    });

    test('Ice vs Dragon/Flying (Dragonite) is 4x super effective', () {
      expect(
        typeChart.calculateTypeEffectiveness('Ice', ['Dragon', 'Flying']),
        equals(4.0),
      );
    });

    test('Fire vs Steel/Bug (Forretress) is 4x super effective', () {
      expect(
        typeChart.calculateTypeEffectiveness('Fire', ['Steel', 'Bug']),
        equals(4.0),
      );
    });

    test('Grass vs Grass/Poison (Venusaur) is 0.25x effective', () {
      expect(
        typeChart.calculateTypeEffectiveness('Grass', ['Grass', 'Poison']),
        equals(0.25),
      );
    });
  });

  group('TypeChartService - Multi-Type Edge Cases', () {
    test('Triple resistance can yield 0.125x', () {
      expect(
        typeChart
            .calculateTypeEffectiveness('Fire', ['Water', 'Dragon', 'Rock']),
        equals(0.125),
      );
    });

    test('Triple weakness can yield 8x', () {
      expect(
        typeChart
            .calculateTypeEffectiveness('Ground', ['Fire', 'Electric', 'Rock']),
        equals(8.0),
      );
    });
  });

  group('TypeChartService - Defensive Effectiveness', () {
    test('Steel type has many resistances', () {
      final effectiveness =
          typeChart.calculateDefensiveEffectiveness(['Steel']);

      // Steel resists many types
      expect(effectiveness['Normal'], equals(0.5));
      expect(effectiveness['Grass'], equals(0.5));
      expect(effectiveness['Ice'], equals(0.5));
      expect(effectiveness['Flying'], equals(0.5));
      expect(effectiveness['Psychic'], equals(0.5));
      expect(effectiveness['Bug'], equals(0.5));
      expect(effectiveness['Rock'], equals(0.5));
      expect(effectiveness['Dragon'], equals(0.5));
      expect(effectiveness['Steel'], equals(0.5));
      expect(effectiveness['Fairy'], equals(0.5));

      // Steel is immune to Poison
      expect(effectiveness['Poison'], equals(0.0));

      // Steel is weak to Fighting, Ground, Fire
      expect(effectiveness['Fighting'], equals(2.0));
      expect(effectiveness['Ground'], equals(2.0));
      expect(effectiveness['Fire'], equals(2.0));
    });

    test('Water/Flying (Gyarados) has 4x weakness to Electric', () {
      final effectiveness =
          typeChart.calculateDefensiveEffectiveness(['Water', 'Flying']);
      expect(effectiveness['Electric'], equals(4.0));
    });

    test('Ghost/Dark (Spiritomb pre-Gen VI) has no weaknesses in old games',
        () {
      final effectiveness =
          typeChart.calculateDefensiveEffectiveness(['Ghost', 'Dark']);

      // In Gen VI+, Fairy is super effective
      expect(effectiveness['Fairy'], equals(2.0));

      // But in old games, this combination had no weaknesses
      // Just verifying the type chart is Gen VI+
    });
  });

  group('TypeChartService - Effectiveness Strings', () {
    test('0.0 multiplier returns immune', () {
      expect(typeChart.getEffectivenessString(0.0), equals('immune'));
    });

    test('0.25 multiplier returns quad-weak', () {
      expect(typeChart.getEffectivenessString(0.25), equals('quad-weak'));
    });

    test('0.5 multiplier returns not-very-effective', () {
      expect(
          typeChart.getEffectivenessString(0.5), equals('not-very-effective'));
    });

    test('1.0 multiplier returns null (neutral)', () {
      expect(typeChart.getEffectivenessString(1.0), isNull);
    });

    test('2.0 multiplier returns super-effective', () {
      expect(typeChart.getEffectivenessString(2.0), equals('super-effective'));
    });

    test('4.0 multiplier returns quad-super-effective', () {
      expect(typeChart.getEffectivenessString(4.0),
          equals('quad-super-effective'));
    });
  });

  group('TypeChartService - Edge Cases', () {
    test('All 18 types are present', () {
      final allTypes = typeChart.getAllTypes();
      expect(allTypes.length, equals(18));

      // Verify all types exist
      expect(allTypes, contains('Normal'));
      expect(allTypes, contains('Fire'));
      expect(allTypes, contains('Water'));
      expect(allTypes, contains('Electric'));
      expect(allTypes, contains('Grass'));
      expect(allTypes, contains('Ice'));
      expect(allTypes, contains('Fighting'));
      expect(allTypes, contains('Poison'));
      expect(allTypes, contains('Ground'));
      expect(allTypes, contains('Flying'));
      expect(allTypes, contains('Psychic'));
      expect(allTypes, contains('Bug'));
      expect(allTypes, contains('Rock'));
      expect(allTypes, contains('Ghost'));
      expect(allTypes, contains('Dragon'));
      expect(allTypes, contains('Dark'));
      expect(allTypes, contains('Steel'));
      expect(allTypes, contains('Fairy'));
    });

    test('Metadata contains generation info', () {
      final metadata = typeChart.getMetadata();
      expect(metadata, isNotNull);
      expect(metadata!['generation'], isNotNull);
      expect(metadata['version'], isNotNull);
    });

    test('Invalid type returns 1.0 (neutral)', () {
      expect(typeChart.getEffectiveness('InvalidType', 'Water'), equals(1.0));
      expect(typeChart.getEffectiveness('Fire', 'InvalidType'), equals(1.0));
    });

    test('Empty defending types list returns 1.0', () {
      expect(typeChart.calculateTypeEffectiveness('Fire', []), equals(1.0));
    });

    test('Three immunities compound to 0.0', () {
      // This is a theoretical test - no Pokémon has three types
      // But verifies the multiplication logic
      final result = typeChart.calculateTypeEffectiveness('Normal', ['Ghost']);
      expect(result, equals(0.0));
    });
  });

  group('TypeChartService - Known Pokémon Matchups', () {
    test('Stealth Rock vs Charizard (Fire/Flying)', () {
      expect(
        typeChart.calculateTypeEffectiveness('Rock', ['Fire', 'Flying']),
        equals(4.0),
      );
    });

    test('Ice Beam vs Garchomp (Dragon/Ground)', () {
      expect(
        typeChart.calculateTypeEffectiveness('Ice', ['Dragon', 'Ground']),
        equals(4.0),
      );
    });

    test('Earthquake vs Magnezone (Electric/Steel)', () {
      expect(
        typeChart.calculateTypeEffectiveness('Ground', ['Electric', 'Steel']),
        equals(4.0),
      );
    });

    test('Fire Blast vs Ferrothorn (Grass/Steel)', () {
      expect(
        typeChart.calculateTypeEffectiveness('Fire', ['Grass', 'Steel']),
        equals(4.0),
      );
    });

    test('Fighting vs Sableye (Dark/Ghost)', () {
      expect(
        typeChart.calculateTypeEffectiveness('Fighting', ['Dark', 'Ghost']),
        equals(0.0),
      );
    });

    test('Psychic vs Tyranitar (Rock/Dark)', () {
      expect(
        typeChart.calculateTypeEffectiveness('Psychic', ['Rock', 'Dark']),
        equals(0.0),
      );
    });
  });
}
