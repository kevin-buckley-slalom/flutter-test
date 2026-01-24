class Move {
  final String name;
  final String type;
  final String category; // Physical, Special, Status
  final int? power;
  final int? accuracy;
  final int pp;
  final int? maxPp;
  final String effect;
  final String? detailedEffect;
  final int? effectChance;
  final bool makesContact;
  final String? targets;
  final int generation;

  Move({
    required this.name,
    required this.type,
    required this.category,
    required this.power,
    required this.accuracy,
    required this.pp,
    this.maxPp,
    required this.effect,
    this.detailedEffect,
    this.effectChance,
    required this.makesContact,
    this.targets,
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
      maxPp: json['max_pp'] as int?,
      effect: json['effect'] as String? ?? '',
      detailedEffect: json['detailed_effect'] as String?,
      effectChance: json['effect_chance'] as int?,
      makesContact: json['makes_contact'] as bool? ?? false,
      targets: json['targets'] as String? ?? 'Unknown',
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
    'max_pp': maxPp,
    'effect': effect,
    'detailed_effect': detailedEffect,
    'effect_chance': effectChance,
    'makes_contact': makesContact,
    'targets': targets,
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
