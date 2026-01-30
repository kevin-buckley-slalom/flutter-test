import 'package:flutter_test/flutter_test.dart';
import 'package:championdex/domain/utils/pokemon_stat_calculator.dart';
import 'package:championdex/data/models/pokemon_stats.dart';
import 'package:championdex/data/models/nature.dart';

void main() {
  group('PokemonStatCalculator - HP Calculation', () {
    test('Snorlax HP at level 100 with max IVs and EVs', () {
      final hp = PokemonStatCalculator.calculateHpStat(
        baseHp: 160,
        iv: 31,
        ev: 252,
        level: 100,
      );
      expect(hp, equals(544)); // Known value from Pokémon Showdown
    });

    test('Snorlax HP at level 50 with max IVs and EVs', () {
      final hp = PokemonStatCalculator.calculateHpStat(
        baseHp: 160,
        iv: 31,
        ev: 252,
        level: 50,
      );
      expect(hp, equals(267));
    });

    test('Blissey HP at level 100 with max IVs and EVs', () {
      final hp = PokemonStatCalculator.calculateHpStat(
        baseHp: 255, // Highest HP stat
        iv: 31,
        ev: 252,
        level: 100,
      );
      expect(hp, equals(714));
    });

    test('HP with 0 IVs and 0 EVs', () {
      final hp = PokemonStatCalculator.calculateHpStat(
        baseHp: 100,
        iv: 0,
        ev: 0,
        level: 100,
      );
      expect(hp, equals(310));
    });

    test('HP at level 1', () {
      final hp = PokemonStatCalculator.calculateHpStat(
        baseHp: 50,
        iv: 31,
        ev: 0,
        level: 1,
      );
      expect(hp, equals(12));
    });

    test('Shedinja always has 1 HP regardless of stats', () {
      final hp = PokemonStatCalculator.calculateHpStat(
        baseHp: 1,
        iv: 31,
        ev: 252,
        level: 100,
      );
      expect(hp, equals(1));
    });
  });

  group('PokemonStatCalculator - Non-HP Stats', () {
    test('Garchomp Attack at level 100 with Adamant nature', () {
      final adamant = Nature(
        name: 'Adamant',
        attackMultiplier: 1.1,
        defenseMultiplier: 1.0,
        spAtkMultiplier: 0.9,
        spDefMultiplier: 1.0,
        speedMultiplier: 1.0,
      );

      final attack = PokemonStatCalculator.calculateStat(
        baseStat: 130,
        iv: 31,
        ev: 252,
        level: 100,
        statName: 'attack',
        nature: adamant,
      );
      expect(attack, equals(394)); // 359 × 1.1
    });

    test('Stat with hindering nature', () {
      final modest = Nature(
        name: 'Modest',
        attackMultiplier: 0.9,
        defenseMultiplier: 1.0,
        spAtkMultiplier: 1.1,
        spDefMultiplier: 1.0,
        speedMultiplier: 1.0,
      );

      final attack = PokemonStatCalculator.calculateStat(
        baseStat: 100,
        iv: 31,
        ev: 0,
        level: 100,
        statName: 'attack',
        nature: modest,
      );
      expect(attack, equals(194)); // 216 × 0.9
    });

    test('Stat with neutral nature', () {
      final hardy = Nature(
        name: 'Hardy',
        attackMultiplier: 1.0,
        defenseMultiplier: 1.0,
        spAtkMultiplier: 1.0,
        spDefMultiplier: 1.0,
        speedMultiplier: 1.0,
      );

      final speed = PokemonStatCalculator.calculateStat(
        baseStat: 100,
        iv: 31,
        ev: 252,
        level: 100,
        statName: 'speed',
        nature: hardy,
      );
      expect(speed, equals(299));
    });

    test('Speed at level 50 with max investment and Jolly nature', () {
      final jolly = Nature(
        name: 'Jolly',
        attackMultiplier: 1.0,
        defenseMultiplier: 1.0,
        spAtkMultiplier: 0.9,
        spDefMultiplier: 1.0,
        speedMultiplier: 1.1,
      );

      final speed = PokemonStatCalculator.calculateStat(
        baseStat: 100,
        iv: 31,
        ev: 252,
        level: 50,
        statName: 'speed',
        nature: jolly,
      );
      expect(speed, equals(167)); // 152 × 1.1
    });

    test('Stat with 0 IVs, 0 EVs, and no nature at level 50', () {
      final stat = PokemonStatCalculator.calculateStat(
        baseStat: 80,
        iv: 0,
        ev: 0,
        level: 50,
        statName: 'defense',
        nature: null,
      );
      expect(stat, equals(85)); // ((2 × 80) × 50 / 100) + 5
    });
  });

  group('PokemonStatCalculator - Calculate All Stats', () {
    test('Calculate all stats for Charizard at level 50', () {
      final baseStats = PokemonStats(
        total: 534,
        hp: 78,
        attack: 84,
        defense: 78,
        spAtk: 109,
        spDef: 85,
        speed: 100,
      );

      final ivs = PokemonStats(
        total: 186,
        hp: 31,
        attack: 31,
        defense: 31,
        spAtk: 31,
        spDef: 31,
        speed: 31,
      );

      final evs = PokemonStats(
        total: 252,
        hp: 0,
        attack: 0,
        defense: 0,
        spAtk: 252,
        spDef: 0,
        speed: 0,
      );

      final adamant = Nature(
        name: 'Adamant',
        attackMultiplier: 1.1,
        defenseMultiplier: 1.0,
        spAtkMultiplier: 0.9,
        spDefMultiplier: 1.0,
        speedMultiplier: 1.0,
      );

      final stats = PokemonStatCalculator.calculateAllStats(
        baseStats: baseStats,
        ivs: ivs,
        evs: evs,
        level: 50,
        nature: adamant,
      );

      expect(stats.hp, equals(153));
      expect(stats.attack, equals(119)); // Boosted by Adamant
      expect(stats.spAtk, equals(129)); // Reduced by Adamant
      expect(stats.speed, equals(120));
    });

    test('Calculate all stats for competitive Garchomp', () {
      final baseStats = PokemonStats(
        total: 600,
        hp: 108,
        attack: 130,
        defense: 95,
        spAtk: 80,
        spDef: 85,
        speed: 102,
      );

      final ivs = PokemonStats(
        total: 186,
        hp: 31,
        attack: 31,
        defense: 31,
        spAtk: 31,
        spDef: 31,
        speed: 31,
      );

      final evs = PokemonStats(
        total: 508,
        hp: 0,
        attack: 252,
        defense: 4,
        spAtk: 0,
        spDef: 0,
        speed: 252,
      );

      final jolly = Nature(
        name: 'Jolly',
        attackMultiplier: 1.0,
        defenseMultiplier: 1.0,
        spAtkMultiplier: 0.9,
        spDefMultiplier: 1.0,
        speedMultiplier: 1.1,
      );

      final stats = PokemonStatCalculator.calculateAllStats(
        baseStats: baseStats,
        ivs: ivs,
        evs: evs,
        level: 50,
        nature: jolly,
      );

      expect(stats.attack, equals(150)); // Max investment
      expect(stats.speed, equals(169)); // Max investment + Jolly boost
      expect(stats.hp, equals(183)); // No investment
    });
  });

  group('PokemonStatCalculator - Validation', () {
    test('Valid EVs pass validation', () {
      final evs = PokemonStats(
        total: 508,
        hp: 252,
        attack: 252,
        defense: 4,
        spAtk: 0,
        spDef: 0,
        speed: 0,
      );
      expect(PokemonStatCalculator.validateEvs(evs), isNull);
    });

    test('EVs exceeding 252 fail validation', () {
      final evs = PokemonStats(
        total: 300,
        hp: 253, // Invalid
        attack: 0,
        defense: 0,
        spAtk: 0,
        spDef: 0,
        speed: 0,
      );
      expect(PokemonStatCalculator.validateEvs(evs), isNotNull);
    });

    test('Total EVs exceeding 510 fail validation', () {
      final evs = PokemonStats(
        total: 512, // Invalid
        hp: 252,
        attack: 252,
        defense: 8,
        spAtk: 0,
        spDef: 0,
        speed: 0,
      );
      expect(PokemonStatCalculator.validateEvs(evs), isNotNull);
    });

    test('Valid IVs pass validation', () {
      final ivs = PokemonStats(
        total: 186,
        hp: 31,
        attack: 31,
        defense: 31,
        spAtk: 31,
        spDef: 31,
        speed: 31,
      );
      expect(PokemonStatCalculator.validateIvs(ivs), isNull);
    });

    test('IVs exceeding 31 fail validation', () {
      final ivs = PokemonStats(
        total: 190,
        hp: 32, // Invalid
        attack: 31,
        defense: 31,
        spAtk: 31,
        spDef: 31,
        speed: 31,
      );
      expect(PokemonStatCalculator.validateIvs(ivs), isNotNull);
    });

    test('Negative EVs fail validation', () {
      final evs = PokemonStats(
        total: -10,
        hp: -10,
        attack: 0,
        defense: 0,
        spAtk: 0,
        spDef: 0,
        speed: 0,
      );
      expect(PokemonStatCalculator.validateEvs(evs), isNotNull);
    });
  });

  group('PokemonStatCalculator - Min/Max Stats', () {
    test('Calculate minimum Attack stat', () {
      final minAtk = PokemonStatCalculator.calculateMinStat(
        baseStat: 100,
        level: 100,
        statName: 'attack',
        isHp: false,
      );
      expect(minAtk, equals(184)); // 0 IVs, 0 EVs, hindering nature
    });

    test('Calculate maximum Attack stat', () {
      final maxAtk = PokemonStatCalculator.calculateMaxStat(
        baseStat: 100,
        level: 100,
        statName: 'attack',
        isHp: false,
      );
      expect(maxAtk, equals(328)); // 31 IVs, 252 EVs, boosting nature
    });

    test('Calculate minimum HP stat', () {
      final minHp = PokemonStatCalculator.calculateMinStat(
        baseStat: 100,
        level: 100,
        statName: 'hp',
        isHp: true,
      );
      expect(minHp, equals(310)); // 0 IVs, 0 EVs (nature doesn't affect HP)
    });

    test('Calculate maximum HP stat', () {
      final maxHp = PokemonStatCalculator.calculateMaxStat(
        baseStat: 100,
        level: 100,
        statName: 'hp',
        isHp: true,
      );
      expect(maxHp, equals(404)); // 31 IVs, 252 EVs
    });
  });

  group('PokemonStatCalculator - Wild Pokémon Stats', () {
    test('Wild Pokémon have average stats', () {
      final wildStat = PokemonStatCalculator.calculateWildPokemonStat(
        baseStat: 100,
        level: 50,
        statName: 'attack',
        isHp: false,
      );
      // Should be between min and max, closer to average
      expect(wildStat, greaterThan(75));
      expect(wildStat, lessThan(120));
    });

    test('Wild Pokémon HP calculation', () {
      final wildHp = PokemonStatCalculator.calculateWildPokemonStat(
        baseStat: 100,
        level: 50,
        statName: 'hp',
        isHp: true,
      );
      // Should be average HP
      expect(wildHp, greaterThan(130));
      expect(wildHp, lessThan(160));
    });
  });

  group('PokemonStatCalculator - Edge Cases', () {
    test('Level 1 Pokémon stats', () {
      final stat = PokemonStatCalculator.calculateStat(
        baseStat: 50,
        iv: 31,
        ev: 0,
        level: 1,
        statName: 'attack',
        nature: null,
      );
      expect(stat, greaterThanOrEqualTo(6));
    });

    test('Base stat of 1 (Shedinja HP)', () {
      final hp = PokemonStatCalculator.calculateHpStat(
        baseHp: 1,
        iv: 0,
        ev: 0,
        level: 50,
      );
      expect(hp, equals(1));
    });

    test('Maximum base stat (255 - Blissey HP)', () {
      final hp = PokemonStatCalculator.calculateHpStat(
        baseHp: 255,
        iv: 31,
        ev: 252,
        level: 100,
      );
      expect(hp, equals(714));
    });
  });
}
