import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/pokemon.dart';

class PokemonDataService {
  static const String _pokemonListPath = 'assets/data/pokemon.json';
  static const String _pokemonByNumberPath = 'assets/data/pokemon_by_number.json';
  static const String _pokemonByNamePath = 'assets/data/pokemon_by_name.json';
  static const String _pokemonByBaseNamePath = 'assets/data/pokemon_by_base_name.json';

  List<Pokemon>? _pokemonList;
  Map<int, List<Pokemon>>? _pokemonByNumber;
  Map<String, Pokemon>? _pokemonByName;
  Map<String, List<Pokemon>>? _pokemonByBaseName;

  Future<void> loadData() async {
    if (_pokemonList != null) return;

    final listJson = await rootBundle.loadString(_pokemonListPath);
    final listData = json.decode(listJson) as List;
    _pokemonList = listData.map((e) => Pokemon.fromJson(e as Map<String, dynamic>)).toList();

    final byNumberJson = await rootBundle.loadString(_pokemonByNumberPath);
    final byNumberData = json.decode(byNumberJson) as Map<String, dynamic>;
    _pokemonByNumber = {};
    for (final entry in byNumberData.entries) {
      final number = int.parse(entry.key);
      final list = (entry.value as List)
          .map((e) => Pokemon.fromJson(e as Map<String, dynamic>))
          .toList();
      _pokemonByNumber![number] = list;
    }

    final byNameJson = await rootBundle.loadString(_pokemonByNamePath);
    final byNameData = json.decode(byNameJson) as Map<String, dynamic>;
    _pokemonByName = {};
    for (final entry in byNameData.entries) {
      _pokemonByName![entry.key] = Pokemon.fromJson(entry.value as Map<String, dynamic>);
    }

    final byBaseNameJson = await rootBundle.loadString(_pokemonByBaseNamePath);
    final byBaseNameData = json.decode(byBaseNameJson) as Map<String, dynamic>;
    _pokemonByBaseName = {};
    for (final entry in byBaseNameData.entries) {
      final list = (entry.value as List)
          .map((e) => Pokemon.fromJson(e as Map<String, dynamic>))
          .toList();
      _pokemonByBaseName![entry.key] = list;
    }
  }

  List<Pokemon> getAll() {
    if (_pokemonList == null) {
      throw StateError('Data not loaded. Call loadData() first.');
    }
    return List.unmodifiable(_pokemonList!);
  }

  List<Pokemon> getByNumber(int number) {
    if (_pokemonByNumber == null) {
      throw StateError('Data not loaded. Call loadData() first.');
    }
    return List.unmodifiable(_pokemonByNumber![number] ?? []);
  }

  Pokemon? getByName(String name) {
    if (_pokemonByName == null) {
      throw StateError('Data not loaded. Call loadData() first.');
    }
    return _pokemonByName![name.toLowerCase()];
  }

  List<Pokemon> getByBaseName(String baseName) {
    if (_pokemonByBaseName == null) {
      throw StateError('Data not loaded. Call loadData() first.');
    }
    return List.unmodifiable(_pokemonByBaseName![baseName.toLowerCase()] ?? []);
  }
}




