import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'data/repositories/pokemon_repository.dart';
import 'data/services/pokemon_data_service.dart';
import 'ui/pokemon_list/pokemon_list_view.dart';
import 'ui/pokemon_list/pokemon_list_view_model.dart';

void main() {
  runApp(
    const ChampionDexApp(),
  );
}

class ChampionDexApp extends StatelessWidget {
  const ChampionDexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        pokemonRepositoryProvider.overrideWithValue(
          PokemonRepository(PokemonDataService()),
        ),
      ],
      child: const App(
        home: PokemonListView(),
      ),
    );
  }
}

