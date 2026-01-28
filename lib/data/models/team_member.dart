class TeamMember {
  final String pokemonName; // Pokemon identifier (name from pokemon.json)
  final int level; // 1-100
  final String? gender; // 'male', 'female', 'none'
  final String teraType; // Type name
  final String ability; // Ability name
  final String? item; // Item name (optional)
  final bool isShiny;

  // IVs (Individual Values) 0-31
  final int ivHp;
  final int ivAttack;
  final int ivDefense;
  final int ivSpAtk;
  final int ivSpDef;
  final int ivSpeed;

  // EVs (Effort Values) 0-255, max 512 total
  final int evHp;
  final int evAttack;
  final int evDefense;
  final int evSpAtk;
  final int evSpDef;
  final int evSpeed;

  final String? nature; // Nature name (optional for now)
  final List<String> moves; // Up to 4 move names (empty by default)

  TeamMember({
    required this.pokemonName,
    this.level = 50,
    this.gender,
    required this.teraType,
    required this.ability,
    this.item,
    this.isShiny = false,
    this.ivHp = 31,
    this.ivAttack = 31,
    this.ivDefense = 31,
    this.ivSpAtk = 31,
    this.ivSpDef = 31,
    this.ivSpeed = 31,
    this.evHp = 0,
    this.evAttack = 0,
    this.evDefense = 0,
    this.evSpAtk = 0,
    this.evSpDef = 0,
    this.evSpeed = 0,
    this.nature,
    this.moves = const [],
  });

  // Calculate total EVs
  int get totalEvs => evHp + evAttack + evDefense + evSpAtk + evSpDef + evSpeed;

  // Check if EV total is valid (max 512)
  bool get hasValidEvs => totalEvs <= 512;

  TeamMember copyWith({
    String? pokemonName,
    int? level,
    String? gender,
    String? teraType,
    String? ability,
    String? item,
    bool? isShiny,
    int? ivHp,
    int? ivAttack,
    int? ivDefense,
    int? ivSpAtk,
    int? ivSpDef,
    int? ivSpeed,
    int? evHp,
    int? evAttack,
    int? evDefense,
    int? evSpAtk,
    int? evSpDef,
    int? evSpeed,
    String? nature,
    List<String>? moves,
  }) {
    return TeamMember(
      pokemonName: pokemonName ?? this.pokemonName,
      level: level ?? this.level,
      gender: gender ?? this.gender,
      teraType: teraType ?? this.teraType,
      ability: ability ?? this.ability,
      item: item ?? this.item,
      isShiny: isShiny ?? this.isShiny,
      ivHp: ivHp ?? this.ivHp,
      ivAttack: ivAttack ?? this.ivAttack,
      ivDefense: ivDefense ?? this.ivDefense,
      ivSpAtk: ivSpAtk ?? this.ivSpAtk,
      ivSpDef: ivSpDef ?? this.ivSpDef,
      ivSpeed: ivSpeed ?? this.ivSpeed,
      evHp: evHp ?? this.evHp,
      evAttack: evAttack ?? this.evAttack,
      evDefense: evDefense ?? this.evDefense,
      evSpAtk: evSpAtk ?? this.evSpAtk,
      evSpDef: evSpDef ?? this.evSpDef,
      evSpeed: evSpeed ?? this.evSpeed,
      nature: nature ?? this.nature,
      moves: moves ?? this.moves,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pokemonName': pokemonName,
      'level': level,
      'gender': gender,
      'teraType': teraType,
      'ability': ability,
      'item': item,
      'isShiny': isShiny,
      'ivHp': ivHp,
      'ivAttack': ivAttack,
      'ivDefense': ivDefense,
      'ivSpAtk': ivSpAtk,
      'ivSpDef': ivSpDef,
      'ivSpeed': ivSpeed,
      'evHp': evHp,
      'evAttack': evAttack,
      'evDefense': evDefense,
      'evSpAtk': evSpAtk,
      'evSpDef': evSpDef,
      'evSpeed': evSpeed,
      'nature': nature,
      'moves': moves,
    };
  }

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      pokemonName: json['pokemonName'] as String,
      level: json['level'] as int? ?? 50,
      gender: json['gender'] as String?,
      teraType: json['teraType'] as String,
      ability: json['ability'] as String,
      item: json['item'] as String?,
      isShiny: json['isShiny'] as bool? ?? false,
      ivHp: json['ivHp'] as int? ?? 31,
      ivAttack: json['ivAttack'] as int? ?? 31,
      ivDefense: json['ivDefense'] as int? ?? 31,
      ivSpAtk: json['ivSpAtk'] as int? ?? 31,
      ivSpDef: json['ivSpDef'] as int? ?? 31,
      ivSpeed: json['ivSpeed'] as int? ?? 31,
      evHp: json['evHp'] as int? ?? 0,
      evAttack: json['evAttack'] as int? ?? 0,
      evDefense: json['evDefense'] as int? ?? 0,
      evSpAtk: json['evSpAtk'] as int? ?? 0,
      evSpDef: json['evSpDef'] as int? ?? 0,
      evSpeed: json['evSpeed'] as int? ?? 0,
      nature: json['nature'] as String?,
      moves: List<String>.from(json['moves'] as List<dynamic>? ?? []),
    );
  }
}
