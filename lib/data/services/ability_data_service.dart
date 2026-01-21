import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/ability.dart';

class AbilityDataService {
  static const String _abilitiesPath = 'assets/data/abilities.json';

  Map<String, Ability>? _abilitiesByName;

  Future<void> loadData() async {
    if (_abilitiesByName != null) return;

    final json = await rootBundle.loadString(_abilitiesPath);
    final data = jsonDecode(json) as Map<String, dynamic>;
    
    _abilitiesByName = {};
    for (final entry in data.entries) {
      final abilityName = entry.key;
      final abilityData = entry.value as Map<String, dynamic>;
      _abilitiesByName![abilityName] = Ability.fromJson(abilityName, abilityData);
    }
  }

  List<Ability> getAllAbilities() {
    if (_abilitiesByName == null) {
      throw Exception('Ability data not loaded. Call loadData() first.');
    }
    return _abilitiesByName!.values.toList();
  }

  Ability? getAbilityByName(String name) {
    if (_abilitiesByName == null) {
      throw Exception('Ability data not loaded. Call loadData() first.');
    }
    return _abilitiesByName![name];
  }
}
