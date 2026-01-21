import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/move.dart';

class PokemonMoveDataService {
  static final PokemonMoveDataService _instance =
      PokemonMoveDataService._internal();
  final Map<String, Map<String, dynamic>> _moveCache = {};

  factory PokemonMoveDataService() {
    return _instance;
  }

  PokemonMoveDataService._internal();

  /// Load pokemon moves for a specific pokemon base name
  Future<Map<String, dynamic>> loadPokemonMoves(String baseName) async {
    if (_moveCache.containsKey(baseName)) {
      return _moveCache[baseName]!;
    }

    try {
      final jsonString = await rootBundle
          .loadString('assets/data/pokemon_moves/$baseName.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      _moveCache[baseName] = jsonData;
      return jsonData;
    } catch (e) {
      throw Exception('Failed to load moves for $baseName: $e');
    }
  }

  /// Get moves for a specific pokemon variant, generation, and game
  /// Returns a map of learnType -> List of PokemonMove objects
  Future<Map<String, List<PokemonMove>>> getMovesForVariant({
    required String baseName,
    required String variant,
    required String generation, // e.g., "gen_9"
    required String game, // e.g., "Scarlet and Violet"
  }) async {
    final allMoves = await loadPokemonMoves(baseName);

    if (!allMoves.containsKey(variant)) {
      return {};
    }

    final variantData = allMoves[variant] as Map<String, dynamic>;

    if (!variantData.containsKey(generation)) {
      return {};
    }

    final genData = variantData[generation] as Map<String, dynamic>;

    if (!genData.containsKey(game)) {
      return {};
    }

    final gameData = genData[game] as Map<String, dynamic>;

    final result = <String, List<PokemonMove>>{};

    gameData.forEach((learnType, movesList) {
      if (movesList is List) {
        result[learnType] = movesList
            .whereType<Map<String, dynamic>>()
            .map((moveJson) => PokemonMove.fromJson(moveJson, learnType))
            .toList();
      }
    });

    return result;
  }

  /// Get all available generations for a pokemon
  Future<List<String>> getAvailableGenerations(String baseName) async {
    final allMoves = await loadPokemonMoves(baseName);
    final generations = <String>[];

    allMoves.forEach((variant, variantData) {
      if (variantData is Map<String, dynamic>) {
        variantData.forEach((genKey, _) {
          if (genKey.startsWith('gen_') && !generations.contains(genKey)) {
            generations.add(genKey);
          }
        });
      }
    });

    // Sort by generation number
    generations.sort((a, b) {
      final numA = int.tryParse(a.replaceAll('gen_', '')) ?? 0;
      final numB = int.tryParse(b.replaceAll('gen_', '')) ?? 0;
      return numA.compareTo(numB);
    });

    return generations;
  }

  /// Get all available games for a pokemon in a specific generation
  Future<List<String>> getAvailableGames(
    String baseName,
    String variant,
    String generation,
  ) async {
    final allMoves = await loadPokemonMoves(baseName);

    if (!allMoves.containsKey(variant)) {
      return [];
    }

    final variantData = allMoves[variant] as Map<String, dynamic>;

    if (!variantData.containsKey(generation)) {
      return [];
    }

    final genData = variantData[generation] as Map<String, dynamic>;
    return genData.keys.cast<String>().toList();
  }

  /// Clear cache for testing/refreshing
  void clearCache() {
    _moveCache.clear();
  }
}
