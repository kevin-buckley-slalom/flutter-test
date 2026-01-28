import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/move.dart';

class PokemonMoveDataService {
  static final PokemonMoveDataService _instance =
      PokemonMoveDataService._internal();
  final Map<String, Map<String, dynamic>> _moveCache = {};
  Map<String, Map<String, List<PokemonMove>>>?
      _moveToPokeIndexCache; // move -> {pokemonName -> [moves]}

  factory PokemonMoveDataService() {
    return _instance;
  }

  PokemonMoveDataService._internal();

  /// Load the pre-generated moves-by-pokemon index from assets
  Future<void> _loadMoveToPokeIndex() async {
    // legacy: not used for per-move files. keep no-op so older code doesn't break
    if (_moveToPokeIndexCache != null) return;
    _moveToPokeIndexCache = {};
  }

  /// Load pokemon moves for a specific pokemon base name
  Future<Map<String, dynamic>> loadPokemonMoves(String baseName) async {
    if (_moveCache.containsKey(baseName)) {
      return _moveCache[baseName]!;
    }

    try {
      final jsonString = await rootBundle.loadString(
          'assets/data/pokemon_moves/${baseName.replaceAll(":", "")}.json');
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

  /// Get all unique moves available for a specific Pokemon variant across all generations and games
  Future<Set<String>> getAvailableMovesForPokemon(
      String baseName, String variantName) async {
    final moves = <String>{};

    try {
      final jsonString = await rootBundle.loadString(
          'assets/data/pokemon_moves/${baseName.replaceAll(":", "")}.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      // Only look at the specific variant (e.g., "Venusaur" or "Venusaur Mega Venusaur")
      final variantData = jsonData[variantName];
      if (variantData is Map<String, dynamic>) {
        // Only process this specific variant, not all variants
        // Iterate through generations (e.g., "gen_8", "gen_9")
        variantData.forEach((genKey, genData) {
          if (genKey.startsWith('gen_') && genData is Map<String, dynamic>) {
            // Iterate through games (e.g., "Sword and Shield", "Scarlet and Violet")
            genData.forEach((gameKey, gameData) {
              if (gameData is Map<String, dynamic>) {
                // Iterate through acquisition methods (e.g., "level_up", "tm", "tr")
                gameData.forEach((method, movesList) {
                  if (movesList is List) {
                    // Extract move names from the list
                    for (final moveObj in movesList) {
                      if (moveObj is Map<String, dynamic>) {
                        // Check both "move" and "name" fields for compatibility
                        final moveName = moveObj['move'] ?? moveObj['name'];
                        if (moveName != null && moveName is String) {
                          moves.add(moveName);
                        }
                      }
                    }
                  }
                });
              }
            });
          }
        });
      }

      debugPrint('Loaded ${moves.length} unique moves for $variantName');
    } catch (e) {
      // File may not exist for this Pokemon, return empty set
      debugPrint('No moves file found for $baseName: $e');
      return {};
    }

    return moves;
  }

  /// Clear cache for testing/refreshing
  void clearCache() {
    _moveCache.clear();
    _moveToPokeIndexCache = null;
  }

  /// Get all Pokemon that learn a specific move (loads from pre-generated index)
  /// Returns a map of Pokemon name -> List of PokemonMove objects for that move
  Future<Map<String, List<PokemonMove>>> getPokemonLearningMove(
      String moveName) async {
    // Prefer per-move files generated under assets/data/moves_pokemon/<move>.json
    final fileName = _sanitizeFileName(moveName);
    final assetPath = 'assets/data/moves_pokemon/$fileName';

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      // jsonData: { gameName: { methodName: [pokemonFormNames] } }
      final result = <String, List<PokemonMove>>{};

      jsonData.forEach((gameName, methodsMap) {
        if (methodsMap is Map<String, dynamic>) {
          methodsMap.forEach((methodName, forms) {
            if (forms is List) {
              final learnType = _normalizeLearnType(methodName);
              for (final f in forms) {
                if (f is String) {
                  result.putIfAbsent(f, () => <PokemonMove>[]).add(
                        PokemonMove(
                          name: moveName,
                          tmId: null,
                          learnType: learnType,
                          level: '—',
                        ),
                      );
                }
              }
            }
          });
        }
      });

      return result;
    } catch (e) {
      // Fall back to empty map if file not found
      return {};
    }
  }

  /// Returns mapping of game -> list of methods available for this move
  Future<Map<String, List<String>>> getAvailableGamesForMove(
      String moveName) async {
    final fileName = _sanitizeFileName(moveName);
    final assetPath = 'assets/data/moves_pokemon/$fileName';
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final out = <String, List<String>>{};
      jsonData.forEach((gameName, methodsMap) {
        if (methodsMap is Map<String, dynamic>) {
          out[gameName] = methodsMap.keys.cast<String>().toList();
        }
      });
      return out;
    } catch (e) {
      return {};
    }
  }

  String _sanitizeFileName(String name) {
    var s = name.trim();
    s = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return '$s.json';
  }

  String _normalizeLearnType(String method) {
    final m = method.toLowerCase();
    if (m == 'egg_moves' || m == 'egg') return 'egg';
    if (m == 'tutor_attacks' || m == 'tutor_attacks' || m == 'tutor')
      return 'tutor';
    if (m == 'level_up' || m == 'level') return 'level_up';
    if (m == 'tr') return 'tr';
    if (m == 'hm') return 'hm';
    if (m == 'tm') return 'tm';
    if (m == 'transfer') return 'transfer';
    if (m == 'reminder') return 'reminder';
    return m;
  }

  /// Get Pokemon learning the move filtered by game and method (if provided).
  Future<Map<String, List<PokemonMove>>> getPokemonLearningMoveFiltered(
    String moveName, {
    String? game,
    String? method,
  }) async {
    final fileName = _sanitizeFileName(moveName);
    final assetPath = 'assets/data/moves_pokemon/$fileName';
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final result = <String, List<PokemonMove>>{};

      jsonData.forEach((gameName, methodsMap) {
        if (game != null && gameName != game) return;
        if (methodsMap is Map<String, dynamic>) {
          methodsMap.forEach((methodName, forms) {
            if (method != null &&
                _normalizeLearnType(methodName) != _normalizeLearnType(method))
              return;
            if (forms is List) {
              final learnType = _normalizeLearnType(methodName);
              for (final f in forms) {
                if (f is String) {
                  result.putIfAbsent(f, () => <PokemonMove>[]).add(
                        PokemonMove(
                          name: moveName,
                          tmId: null,
                          learnType: learnType,
                          level: '—',
                        ),
                      );
                }
              }
            }
          });
        }
      });

      return result;
    } catch (e) {
      return {};
    }
  }
}
