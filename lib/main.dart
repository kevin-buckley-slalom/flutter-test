import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'data/repositories/ability_repository.dart';
import 'data/repositories/pokemon_repository.dart';
import 'data/repositories/team_repository.dart';
import 'data/services/ability_data_service.dart';
import 'data/services/pokemon_data_service.dart';
import 'data/services/team_storage_service.dart';
import 'ui/pokemon_list/pokemon_list_view.dart';
import 'ui/pokemon_list/pokemon_list_view_model.dart';
import 'ui/teams_list/teams_list_view_model.dart';

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
        abilityRepositoryProvider.overrideWithValue(
          AbilityRepository(abilityDataService: AbilityDataService()),
        ),
        teamRepositoryProvider.overrideWithValue(
          TeamRepository(TeamStorageService()),
        ),
      ],
      child: const App(
        home: PokemonListView(),
      ),
    );
  }
}

final abilityRepositoryProvider = Provider((ref) {
  return AbilityRepository(abilityDataService: AbilityDataService());
});
