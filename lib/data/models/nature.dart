class Nature {
  final String name;
  final double attackMultiplier;
  final double defenseMultiplier;
  final double spAtkMultiplier;
  final double spDefMultiplier;
  final double speedMultiplier;

  Nature({
    required this.name,
    required this.attackMultiplier,
    required this.defenseMultiplier,
    required this.spAtkMultiplier,
    required this.spDefMultiplier,
    required this.speedMultiplier,
  });

  factory Nature.fromJson(String name, Map<String, dynamic> json) {
    return Nature(
      name: name,
      attackMultiplier: (json['attack'] as num).toDouble(),
      defenseMultiplier: (json['defense'] as num).toDouble(),
      spAtkMultiplier: (json['sp_atk'] as num).toDouble(),
      spDefMultiplier: (json['sp_def'] as num).toDouble(),
      speedMultiplier: (json['speed'] as num).toDouble(),
    );
  }

  double getMultiplierForStat(String statName) {
    switch (statName.toLowerCase()) {
      case 'attack':
        return attackMultiplier;
      case 'defense':
        return defenseMultiplier;
      case 'sp_atk':
      case 'spatk':
        return spAtkMultiplier;
      case 'sp_def':
      case 'spdef':
        return spDefMultiplier;
      case 'speed':
        return speedMultiplier;
      case 'hp':
      default:
        return 1.0; // HP is not affected by nature
    }
  }
}
