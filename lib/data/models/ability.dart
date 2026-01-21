class Ability {
  final String name;
  final String slug;
  final String url;
  final String effect;
  final List<String> regularPokemon;
  final List<String> hiddenPokemon;

  Ability({
    required this.name,
    required this.slug,
    required this.url,
    required this.effect,
    required this.regularPokemon,
    required this.hiddenPokemon,
  });

  factory Ability.fromJson(String name, Map<String, dynamic> json) {
    final nameJson = json['name'] as String? ?? name;
    final slug = json['slug'] as String? ?? '';
    final url = json['url'] as String? ?? '';
    final effect = json['effect'] as String? ?? '';
    
    final pokemonJson = json['pokemon'] as Map<String, dynamic>? ?? {};
    final regularList = (pokemonJson['regular'] as List?)
        ?.whereType<String>()
        .toList() ?? [];
    final hiddenList = (pokemonJson['hidden'] as List?)
        ?.whereType<String>()
        .toList() ?? [];

    return Ability(
      name: nameJson,
      slug: slug,
      url: url,
      effect: effect,
      regularPokemon: regularList,
      hiddenPokemon: hiddenList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      'url': url,
      'effect': effect,
      'pokemon': {
        'regular': regularPokemon,
        'hidden': hiddenPokemon,
      },
    };
  }
}
