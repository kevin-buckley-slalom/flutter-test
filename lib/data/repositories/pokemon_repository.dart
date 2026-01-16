import '../models/pokemon.dart';
import '../services/pokemon_data_service.dart';

class PokemonRepository {
  final PokemonDataService _dataService;

  PokemonRepository(this._dataService);

  Future<void> initialize() async {
    await _dataService.loadData();
  }

  List<Pokemon> all() {
    return _dataService.getAll();
  }

  List<Pokemon> byNumber(int number) {
    return _dataService.getByNumber(number);
  }

  Pokemon? byName(String name) {
    return _dataService.getByName(name);
  }

  List<Pokemon> byBaseName(String baseName) {
    return _dataService.getByBaseName(baseName);
  }

  Pokemon? byNumberAndVariant(int number, String? variant) {
    final pokemonList = byNumber(number);
    if (variant == null) {
      return pokemonList.firstWhere(
        (p) => p.variant == null,
        orElse: () => pokemonList.first,
      );
    }
    return pokemonList.firstWhere(
      (p) => p.variant?.toLowerCase() == variant.toLowerCase(),
      orElse: () => pokemonList.first,
    );
  }

  List<Pokemon> getVariants(int number) {
    return byNumber(number);
  }
}




