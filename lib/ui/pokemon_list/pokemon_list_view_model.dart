import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pokemon.dart';
import '../../data/repositories/pokemon_repository.dart';

final pokemonRepositoryProvider = Provider<PokemonRepository>((ref) {
  throw UnimplementedError('pokemonRepositoryProvider must be overridden');
});

final pokemonListViewModelProvider = FutureProvider<List<Pokemon>>((ref) async {
  final repository = ref.watch(pokemonRepositoryProvider);
  await repository.initialize();
  return repository.all();
});




