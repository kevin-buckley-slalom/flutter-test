import '../../data/models/pokemon.dart';
import '../../data/models/type_effectiveness.dart';

class TypeEffectivenessCalculator {
  // Standard Pokemon type chart - effectiveness multipliers
  // Map[attackingType][defendingType] = multiplier
  static const Map<String, Map<String, double>> _typeChart = {
    'Normal': {
      'Normal': 1.0,
      'Fire': 1.0,
      'Water': 1.0,
      'Electric': 1.0,
      'Grass': 1.0,
      'Ice': 1.0,
      'Fighting': 1.0,
      'Poison': 1.0,
      'Ground': 1.0,
      'Flying': 1.0,
      'Psychic': 1.0,
      'Bug': 1.0,
      'Rock': 0.5,
      'Ghost': 0.0,
      'Dragon': 1.0,
      'Dark': 1.0,
      'Steel': 0.5,
      'Fairy': 1.0,
    },
    'Fire': {
      'Normal': 1.0,
      'Fire': 0.5,
      'Water': 0.5,
      'Electric': 1.0,
      'Grass': 2.0,
      'Ice': 2.0,
      'Fighting': 1.0,
      'Poison': 1.0,
      'Ground': 1.0,
      'Flying': 1.0,
      'Psychic': 1.0,
      'Bug': 2.0,
      'Rock': 0.5,
      'Ghost': 1.0,
      'Dragon': 0.5,
      'Dark': 1.0,
      'Steel': 2.0,
      'Fairy': 1.0,
    },
    'Water': {
      'Normal': 1.0,
      'Fire': 2.0,
      'Water': 0.5,
      'Electric': 1.0,
      'Grass': 0.5,
      'Ice': 1.0,
      'Fighting': 1.0,
      'Poison': 1.0,
      'Ground': 2.0,
      'Flying': 1.0,
      'Psychic': 1.0,
      'Bug': 1.0,
      'Rock': 2.0,
      'Ghost': 1.0,
      'Dragon': 0.5,
      'Dark': 1.0,
      'Steel': 1.0,
      'Fairy': 1.0,
    },
    'Electric': {
      'Normal': 1.0,
      'Fire': 1.0,
      'Water': 2.0,
      'Electric': 0.5,
      'Grass': 0.5,
      'Ice': 1.0,
      'Fighting': 1.0,
      'Poison': 1.0,
      'Ground': 0.0,
      'Flying': 2.0,
      'Psychic': 1.0,
      'Bug': 1.0,
      'Rock': 1.0,
      'Ghost': 1.0,
      'Dragon': 0.5,
      'Dark': 1.0,
      'Steel': 1.0,
      'Fairy': 1.0,
    },
    'Grass': {
      'Normal': 1.0,
      'Fire': 0.5,
      'Water': 2.0,
      'Electric': 1.0,
      'Grass': 0.5,
      'Ice': 1.0,
      'Fighting': 1.0,
      'Poison': 0.5,
      'Ground': 2.0,
      'Flying': 0.5,
      'Psychic': 1.0,
      'Bug': 0.5,
      'Rock': 2.0,
      'Ghost': 1.0,
      'Dragon': 0.5,
      'Dark': 1.0,
      'Steel': 0.5,
      'Fairy': 1.0,
    },
    'Ice': {
      'Normal': 1.0,
      'Fire': 0.5,
      'Water': 0.5,
      'Electric': 1.0,
      'Grass': 2.0,
      'Ice': 0.5,
      'Fighting': 1.0,
      'Poison': 1.0,
      'Ground': 2.0,
      'Flying': 2.0,
      'Psychic': 1.0,
      'Bug': 1.0,
      'Rock': 1.0,
      'Ghost': 1.0,
      'Dragon': 2.0,
      'Dark': 1.0,
      'Steel': 0.5,
      'Fairy': 1.0,
    },
    'Fighting': {
      'Normal': 2.0,
      'Fire': 1.0,
      'Water': 1.0,
      'Electric': 1.0,
      'Grass': 1.0,
      'Ice': 2.0,
      'Fighting': 1.0,
      'Poison': 0.5,
      'Ground': 1.0,
      'Flying': 0.5,
      'Psychic': 0.5,
      'Bug': 0.5,
      'Rock': 2.0,
      'Ghost': 0.0,
      'Dragon': 1.0,
      'Dark': 2.0,
      'Steel': 2.0,
      'Fairy': 0.5,
    },
    'Poison': {
      'Normal': 1.0,
      'Fire': 1.0,
      'Water': 1.0,
      'Electric': 1.0,
      'Grass': 2.0,
      'Ice': 1.0,
      'Fighting': 1.0,
      'Poison': 0.5,
      'Ground': 0.5,
      'Flying': 1.0,
      'Psychic': 1.0,
      'Bug': 1.0,
      'Rock': 0.5,
      'Ghost': 0.5,
      'Dragon': 1.0,
      'Dark': 1.0,
      'Steel': 0.0,
      'Fairy': 2.0,
    },
    'Ground': {
      'Normal': 1.0,
      'Fire': 2.0,
      'Water': 1.0,
      'Electric': 2.0,
      'Grass': 0.5,
      'Ice': 1.0,
      'Fighting': 1.0,
      'Poison': 2.0,
      'Ground': 1.0,
      'Flying': 0.0,
      'Psychic': 1.0,
      'Bug': 0.5,
      'Rock': 2.0,
      'Ghost': 1.0,
      'Dragon': 1.0,
      'Dark': 1.0,
      'Steel': 2.0,
      'Fairy': 1.0,
    },
    'Flying': {
      'Normal': 1.0,
      'Fire': 1.0,
      'Water': 1.0,
      'Electric': 0.5,
      'Grass': 2.0,
      'Ice': 1.0,
      'Fighting': 2.0,
      'Poison': 1.0,
      'Ground': 1.0,
      'Flying': 1.0,
      'Psychic': 1.0,
      'Bug': 2.0,
      'Rock': 0.5,
      'Ghost': 1.0,
      'Dragon': 1.0,
      'Dark': 1.0,
      'Steel': 0.5,
      'Fairy': 1.0,
    },
    'Psychic': {
      'Normal': 1.0,
      'Fire': 1.0,
      'Water': 1.0,
      'Electric': 1.0,
      'Grass': 1.0,
      'Ice': 1.0,
      'Fighting': 2.0,
      'Poison': 2.0,
      'Ground': 1.0,
      'Flying': 1.0,
      'Psychic': 0.5,
      'Bug': 1.0,
      'Rock': 1.0,
      'Ghost': 1.0,
      'Dragon': 1.0,
      'Dark': 0.0,
      'Steel': 0.5,
      'Fairy': 1.0,
    },
    'Bug': {
      'Normal': 1.0,
      'Fire': 0.5,
      'Water': 1.0,
      'Electric': 1.0,
      'Grass': 2.0,
      'Ice': 1.0,
      'Fighting': 0.5,
      'Poison': 0.5,
      'Ground': 1.0,
      'Flying': 0.5,
      'Psychic': 2.0,
      'Bug': 1.0,
      'Rock': 1.0,
      'Ghost': 0.5,
      'Dragon': 1.0,
      'Dark': 2.0,
      'Steel': 0.5,
      'Fairy': 0.5,
    },
    'Rock': {
      'Normal': 1.0,
      'Fire': 2.0,
      'Water': 1.0,
      'Electric': 1.0,
      'Grass': 1.0,
      'Ice': 2.0,
      'Fighting': 0.5,
      'Poison': 1.0,
      'Ground': 0.5,
      'Flying': 2.0,
      'Psychic': 1.0,
      'Bug': 2.0,
      'Rock': 1.0,
      'Ghost': 1.0,
      'Dragon': 1.0,
      'Dark': 1.0,
      'Steel': 0.5,
      'Fairy': 1.0,
    },
    'Ghost': {
      'Normal': 0.0,
      'Fire': 1.0,
      'Water': 1.0,
      'Electric': 1.0,
      'Grass': 1.0,
      'Ice': 1.0,
      'Fighting': 1.0,
      'Poison': 1.0,
      'Ground': 1.0,
      'Flying': 1.0,
      'Psychic': 2.0,
      'Bug': 1.0,
      'Rock': 1.0,
      'Ghost': 2.0,
      'Dragon': 1.0,
      'Dark': 0.5,
      'Steel': 1.0,
      'Fairy': 1.0,
    },
    'Dragon': {
      'Normal': 1.0,
      'Fire': 1.0,
      'Water': 1.0,
      'Electric': 1.0,
      'Grass': 1.0,
      'Ice': 1.0,
      'Fighting': 1.0,
      'Poison': 1.0,
      'Ground': 1.0,
      'Flying': 1.0,
      'Psychic': 1.0,
      'Bug': 1.0,
      'Rock': 1.0,
      'Ghost': 1.0,
      'Dragon': 2.0,
      'Dark': 1.0,
      'Steel': 0.5,
      'Fairy': 0.0,
    },
    'Dark': {
      'Normal': 1.0,
      'Fire': 1.0,
      'Water': 1.0,
      'Electric': 1.0,
      'Grass': 1.0,
      'Ice': 1.0,
      'Fighting': 0.5,
      'Poison': 1.0,
      'Ground': 1.0,
      'Flying': 1.0,
      'Psychic': 2.0,
      'Bug': 1.0,
      'Rock': 1.0,
      'Ghost': 2.0,
      'Dragon': 1.0,
      'Dark': 0.5,
      'Steel': 1.0,
      'Fairy': 0.5,
    },
    'Steel': {
      'Normal': 1.0,
      'Fire': 0.5,
      'Water': 0.5,
      'Electric': 0.5,
      'Grass': 1.0,
      'Ice': 2.0,
      'Fighting': 1.0,
      'Poison': 1.0,
      'Ground': 1.0,
      'Flying': 1.0,
      'Psychic': 1.0,
      'Bug': 1.0,
      'Rock': 2.0,
      'Ghost': 1.0,
      'Dragon': 1.0,
      'Dark': 1.0,
      'Steel': 0.5,
      'Fairy': 2.0,
    },
    'Fairy': {
      'Normal': 1.0,
      'Fire': 0.5,
      'Water': 1.0,
      'Electric': 1.0,
      'Grass': 1.0,
      'Ice': 1.0,
      'Fighting': 2.0,
      'Poison': 0.5,
      'Ground': 1.0,
      'Flying': 1.0,
      'Psychic': 1.0,
      'Bug': 1.0,
      'Rock': 1.0,
      'Ghost': 1.0,
      'Dragon': 2.0,
      'Dark': 2.0,
      'Steel': 0.5,
      'Fairy': 1.0,
    },
  };

  static TypeEffectiveness calculate(Pokemon pokemon) {
    final effectivenessMap = <String, double>{};

    // For each attacking type, calculate effectiveness against this Pokemon's types
    for (final attackingType in _typeChart.keys) {
      double multiplier = 1.0;

      // Multiply effectiveness for each defending type
      for (final defendingType in pokemon.types) {
        final typeMultiplier = _typeChart[attackingType]?[defendingType] ?? 1.0;
        multiplier *= typeMultiplier;
      }

      effectivenessMap[attackingType] = multiplier;
    }

    // Convert multipliers to Effectiveness enum
    final effectivenessEnumMap = <String, Effectiveness>{};
    for (final entry in effectivenessMap.entries) {
      final multiplier = entry.value;
      Effectiveness effectiveness;
      if (multiplier == 0.0) {
        effectiveness = Effectiveness.immune;
      } else if (multiplier == 0.25) {
        effectiveness = Effectiveness.hardlyEffective;
      } else if (multiplier == 0.5) {
        effectiveness = Effectiveness.notVeryEffective;
      } else if (multiplier == 1.0) {
        effectiveness = Effectiveness.normal;
      } else if (multiplier == 2.0) {
        effectiveness = Effectiveness.superEffective;
      } else {
        effectiveness = Effectiveness.extremelyEffective;
      }
      effectivenessEnumMap[entry.key] = effectiveness;
    }

    return TypeEffectiveness(effectivenessEnumMap);
  }

  // Calculate offensive type effectiveness for a specific type
  static Map<String, Effectiveness> calculateOffensiveEffectiveness(String attackingType) {
    final effectivenessMap = <String, Effectiveness>{};
    
    final typeData = _typeChart[attackingType];
    if (typeData == null) {
      return effectivenessMap;
    }

    for (final entry in typeData.entries) {
      final defendingType = entry.key;
      final multiplier = entry.value;
      
      Effectiveness effectiveness;
      if (multiplier == 0.0) {
        effectiveness = Effectiveness.immune;
      } else if (multiplier == 0.5) {
        effectiveness = Effectiveness.notVeryEffective;
      } else if (multiplier == 1.0) {
        effectiveness = Effectiveness.normal;
      } else {
        effectiveness = Effectiveness.superEffective;
      }
      
      effectivenessMap[defendingType] = effectiveness;
    }

    return effectivenessMap;
  }
}




