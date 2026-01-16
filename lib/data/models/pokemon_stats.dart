class PokemonStats {
  final int total;
  final int hp;
  final int attack;
  final int defense;
  final int spAtk;
  final int spDef;
  final int speed;

  PokemonStats({
    required this.total,
    required this.hp,
    required this.attack,
    required this.defense,
    required this.spAtk,
    required this.spDef,
    required this.speed,
  });

  factory PokemonStats.fromJson(Map<String, dynamic> json) {
    return PokemonStats(
      total: json['total'] as int,
      hp: json['hp'] as int,
      attack: json['attack'] as int,
      defense: json['defense'] as int,
      spAtk: json['sp_atk'] as int,
      spDef: json['sp_def'] as int,
      speed: json['speed'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'hp': hp,
      'attack': attack,
      'defense': defense,
      'sp_atk': spAtk,
      'sp_def': spDef,
      'speed': speed,
    };
  }
}




