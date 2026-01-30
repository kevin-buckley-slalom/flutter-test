import '../../data/models/pokemon_stats.dart';
import '../../data/models/team_member.dart';
import '../../data/services/nature_data_service.dart';
import '../../data/models/nature.dart';

/// Utility class for calculating Pokémon battle stats from base stats, IVs, EVs, level, and nature
class StatCalculator {
  /// Calculate the stat prefix: floor((2*base + IV + floor(EV/4)) * level / 100)
  static int _calculateStatPrefix(int baseStat, int iv, int ev, int level) {
    int evPart = (ev / 4).floor();
    int preLevel = (2 * baseStat) + iv + evPart;
    return (preLevel * level / 100).floor();
  }

  /// Calculate a single stat value
  ///
  /// For HP: prefix + level + 10
  /// For other stats: (prefix + 5) * nature modifier
  static int calculateStat({
    required int baseStat,
    required int iv,
    required int ev,
    required int level,
    required String statName,
    Nature? nature,
  }) {
    // Get nature modifier
    double natureModifier = 1.0;
    if (nature != null) {
      natureModifier = nature.getMultiplierForStat(statName);
    }

    // HP calculation is different from other stats
    if (statName.toLowerCase() == 'hp') {
      return _calculateStatPrefix(baseStat, iv, ev, level) + level + 10;
    } else {
      // Other stats calculation with nature modifier
      return ((_calculateStatPrefix(baseStat, iv, ev, level) + 5) *
              natureModifier)
          .floor();
    }
  }

  /// Calculate all battle stats from base stats and team member configuration
  static Future<PokemonStats> calculateBattleStats({
    required PokemonStats baseStats,
    required TeamMember member,
  }) async {
    // Load nature if specified
    Nature? nature;
    if (member.nature != null) {
      final natureService = NatureDataService();
      await natureService.loadNatures();
      nature = natureService.getNatureByName(member.nature);
    }

    // Calculate each stat
    final hp = calculateStat(
      baseStat: baseStats.hp,
      iv: member.ivHp,
      ev: member.evHp,
      level: member.level,
      statName: 'hp',
      nature: nature,
    );

    final attack = calculateStat(
      baseStat: baseStats.attack,
      iv: member.ivAttack,
      ev: member.evAttack,
      level: member.level,
      statName: 'attack',
      nature: nature,
    );

    final defense = calculateStat(
      baseStat: baseStats.defense,
      iv: member.ivDefense,
      ev: member.evDefense,
      level: member.level,
      statName: 'defense',
      nature: nature,
    );

    final spAtk = calculateStat(
      baseStat: baseStats.spAtk,
      iv: member.ivSpAtk,
      ev: member.evSpAtk,
      level: member.level,
      statName: 'sp_atk',
      nature: nature,
    );

    final spDef = calculateStat(
      baseStat: baseStats.spDef,
      iv: member.ivSpDef,
      ev: member.evSpDef,
      level: member.level,
      statName: 'sp_def',
      nature: nature,
    );

    final speed = calculateStat(
      baseStat: baseStats.speed,
      iv: member.ivSpeed,
      ev: member.evSpeed,
      level: member.level,
      statName: 'speed',
      nature: nature,
    );

    final total = hp + attack + defense + spAtk + spDef + speed;

    return PokemonStats(
      total: total,
      hp: hp,
      attack: attack,
      defense: defense,
      spAtk: spAtk,
      spDef: spDef,
      speed: speed,
    );
  }
}
