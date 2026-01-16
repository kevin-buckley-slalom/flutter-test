import 'pokemon_stats.dart';

class Pokemon {
  final int number;
  final String name;
  final String baseName;
  final String? variant;
  final int generation;
  final List<String> types;
  final PokemonStats stats;

  Pokemon({
    required this.number,
    required this.name,
    required this.baseName,
    this.variant,
    required this.generation,
    required this.types,
    required this.stats,
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    return Pokemon(
      number: json['number'] as int,
      name: json['name'] as String,
      baseName: json['base_name'] as String,
      variant: json['variant'] as String?,
      generation: json['generation'] as int,
      types: (json['types'] as List).map((e) => e as String).toList(),
      stats: PokemonStats.fromJson(json['stats'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'name': name,
      'base_name': baseName,
      'variant': variant,
      'generation': generation,
      'types': types,
      'stats': stats.toJson(),
    };
  }

  String get displayName => variant != null ? '$variant $baseName' : name;
  
  bool get isBaseForm => variant == null;
}




