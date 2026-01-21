import '../models/move.dart';
import '../services/move_data_service.dart';
import '../services/pokemon_move_data_service.dart';

class MoveRepository {
  final MoveDataService _moveDataService = MoveDataService();
  final PokemonMoveDataService _pokemonMoveDataService =
      PokemonMoveDataService();

  Future<void> initialize() async {
    await _moveDataService.loadData();
  }

  Future<Move?> getMoveByName(String moveName) async {
    if (!_moveDataService.isLoaded()) {
      await initialize();
    }
    return _moveDataService.getMoveByName(moveName);
  }

  Future<List<Move>> getAllMoves() async {
    if (!_moveDataService.isLoaded()) {
      await initialize();
    }
    return _moveDataService.getAllMoves();
  }

  Future<Map<String, List<PokemonMove>>> getMovesForVariant({
    required String baseName,
    required String variant,
    required String generation,
    required String game,
  }) {
    return _pokemonMoveDataService.getMovesForVariant(
      baseName: baseName,
      variant: variant,
      generation: generation,
      game: game,
    );
  }

  Future<List<String>> getAvailableGenerations(String baseName) {
    return _pokemonMoveDataService.getAvailableGenerations(baseName);
  }

  Future<List<String>> getAvailableGames(
    String baseName,
    String variant,
    String generation,
  ) {
    return _pokemonMoveDataService.getAvailableGames(
      baseName,
      variant,
      generation,
    );
  }
}
