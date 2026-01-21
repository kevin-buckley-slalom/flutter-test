class Move {
  final String name;
  final String type;
  final String category; // Physical, Special, Status
  final int? power;
  final int? accuracy;
  final int pp;
  final String effect;
  final int generation;

  Move({
    required this.name,
    required this.type,
    required this.category,
    required this.power,
    required this.accuracy,
    required this.pp,
    required this.effect,
    required this.generation,
  });

  factory Move.fromJson(Map<String, dynamic> json) {
    return Move(
      name: json['name'] as String? ?? 'Unknown',
      type: json['type'] as String? ?? 'Unknown',
      category: json['category'] as String? ?? 'Status',
      power: json['power'] as int?,
      accuracy: json['accuracy'] as int?,
      pp: json['pp'] as int? ?? 0,
      effect: json['effect'] as String? ?? '',
      generation: json['generation'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'category': category,
    'power': power,
    'accuracy': accuracy,
    'pp': pp,
    'effect': effect,
    'generation': generation,
  };
}

/// Represents a move as learned by a pokemon in a specific game/generation
class PokemonMove {
  final String name;
  final String? tmId; // e.g., "TM00" or null for non-TM moves
  final String learnType; // "level_up", "tm", "egg", "tutor", "transfer", etc.
  final String level; // "15", "Evolve", "—", etc.

  PokemonMove({
    required this.name,
    required this.tmId,
    required this.learnType,
    required this.level,
  });

  factory PokemonMove.fromJson(Map<String, dynamic> json, String learnType) {
    return PokemonMove(
      name: json['name'] as String? ?? 'Unknown',
      tmId: json['tm_id'] as String?,
      learnType: learnType,
      level: json['level'] as String? ?? '—',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'tm_id': tmId,
    'learnType': learnType,
    'level': level,
  };
}
