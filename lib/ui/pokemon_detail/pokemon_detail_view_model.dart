import '../../data/models/pokemon.dart';
import '../../data/models/type_effectiveness.dart';
import '../../domain/use_cases/type_effectiveness_calculator.dart';

class PokemonDetailViewModel {
  final Pokemon pokemon;
  final TypeEffectiveness defensiveTypeEffectiveness;
  final Map<String, Map<String, Effectiveness>> offensiveTypeEffectiveness;

  PokemonDetailViewModel({
    required this.pokemon,
    required this.defensiveTypeEffectiveness,
    required this.offensiveTypeEffectiveness,
  });

  factory PokemonDetailViewModel.fromPokemon(Pokemon pokemon) {
    final defensiveTypeEffectiveness = TypeEffectivenessCalculator.calculate(pokemon);
    
    // Calculate offensive effectiveness for each of the Pokemon's types
    final offensiveTypeEffectiveness = <String, Map<String, Effectiveness>>{};
    for (final type in pokemon.types) {
      offensiveTypeEffectiveness[type] = 
          TypeEffectivenessCalculator.calculateOffensiveEffectiveness(type);
    }
    
    return PokemonDetailViewModel(
      pokemon: pokemon,
      defensiveTypeEffectiveness: defensiveTypeEffectiveness,
      offensiveTypeEffectiveness: offensiveTypeEffectiveness,
    );
  }
}



