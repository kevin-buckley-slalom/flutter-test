import 'pokemon_stats.dart';

class Pokemon {
  final int number;
  final String name;
  final String baseName;
  final String? variant;
  final int generation;
  final List<String> types;
  final PokemonStats stats;
  final String? imagePath;
  final String? imageShinyPath;
  final String? imagePathLarge;
  final String? imageShinyPathLarge;
  final List<String> regularAbilities;
  final List<String> hiddenAbilities;

  Pokemon({
    required this.number,
    required this.name,
    required this.baseName,
    this.variant,
    required this.generation,
    required this.types,
    required this.stats,
    this.imagePath,
    this.imageShinyPath,
    this.imagePathLarge,
    this.imageShinyPathLarge,
    this.regularAbilities = const [],
    this.hiddenAbilities = const [],
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    List<String> parseAbilityList(Map<String, dynamic>? abilities, String key) {
      final value = abilities?[key];
      if (value is List) {
        return value.whereType<String>().toList();
      }
      return const [];
    }

    final abilities = json['abilities'] as Map<String, dynamic>?;

    return Pokemon(
      number: json['number'] as int,
      name: json['name'] as String,
      baseName: json['base_name'] as String,
      variant: json['variant'] as String?,
      generation: json['generation'] as int,
      types: (json['types'] as List).map((e) => e as String).toList(),
      stats: PokemonStats.fromJson(json['stats'] as Map<String, dynamic>),
      imagePath: json['image'] as String?,
      imageShinyPath: json['image_shiny'] as String?,
      imagePathLarge: json['image_large'] as String?,
      imageShinyPathLarge: json['image_shiny_large'] as String?,
      regularAbilities: parseAbilityList(abilities, 'regular'),
      hiddenAbilities: parseAbilityList(abilities, 'hidden'),
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
      'image': imagePath,
      'image_shiny': imageShinyPath,
      'image_large': imagePathLarge,
      'image_shiny_large': imageShinyPathLarge,
      'abilities': {
        'regular': regularAbilities,
        'hidden': hiddenAbilities,
      },
    };
  }

  String get displayName => variant != null ? '$variant $baseName' : name;

  bool get isBaseForm => variant == null;
}




