import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Service for loading and querying Pokémon type effectiveness data.
/// Loads the type chart from JSON and provides methods to calculate
/// offensive type effectiveness against defending Pokémon types.
///
/// The type chart follows Generation VI+ mechanics with all 18 types.
/// Reference: https://bulbapedia.bulbagarden.net/wiki/Type/Type_chart
class TypeChartService {
  static TypeChartService? _instance;
  Map<String, Map<String, double>>? _typeChart;
  Map<String, dynamic>? _metadata;

  TypeChartService._();

  /// Get the singleton instance of TypeChartService
  factory TypeChartService() {
    _instance ??= TypeChartService._();
    return _instance!;
  }

  /// Load type chart data from JSON asset
  Future<void> loadTypeChart() async {
    if (_typeChart != null) {
      return; // Already loaded
    }

    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/type_chart.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      _metadata = data['metadata'];
      _typeChart = {};

      final Map<String, dynamic> chartData = data['typeChart'];
      for (final attackingType in chartData.keys) {
        _typeChart![attackingType] = {};
        final Map<String, dynamic> matchups = chartData[attackingType];
        for (final defendingType in matchups.keys) {
          _typeChart![attackingType]![defendingType] =
              (matchups[defendingType] as num).toDouble();
        }
      }
    } catch (e) {
      print('Error loading type chart: $e');
      _typeChart = {};
    }
  }

  /// Get type effectiveness multiplier for a single attacking type against a single defending type
  ///
  /// Returns:
  /// - 0.0: Immune (e.g., Normal vs Ghost)
  /// - 0.5: Not very effective
  /// - 1.0: Neutral
  /// - 2.0: Super effective
  ///
  /// Example:
  /// ```dart
  /// final effectiveness = typeChart.getEffectiveness('Fire', 'Grass');
  /// // Returns 2.0 (Fire is super effective against Grass)
  /// ```
  double getEffectiveness(String attackingType, String defendingType) {
    if (_typeChart == null) {
      throw StateError('Type chart not loaded. Call loadTypeChart() first.');
    }
    return _typeChart![attackingType]?[defendingType] ?? 1.0;
  }

  /// Calculate combined type effectiveness for an attacking type against multiple defending types
  ///
  /// For dual-type Pokémon, multipliers are multiplied together:
  /// - Fire vs Water/Flying: 0.5 × 1.0 = 0.5× (not very effective)
  /// - Rock vs Fire/Flying: 2.0 × 2.0 = 4.0× (double super effective)
  /// - Fighting vs Normal/Flying: 2.0 × 0.5 = 1.0× (neutral)
  ///
  /// Example:
  /// ```dart
  /// final effectiveness = typeChart.calculateTypeEffectiveness('Electric', ['Water', 'Flying']);
  /// // Returns 4.0 (Electric is double super effective vs Water/Flying like Gyarados)
  /// ```
  double calculateTypeEffectiveness(
      String attackingType, List<String> defendingTypes) {
    if (_typeChart == null) {
      throw StateError('Type chart not loaded. Call loadTypeChart() first.');
    }

    double multiplier = 1.0;
    for (final defendingType in defendingTypes) {
      multiplier *= getEffectiveness(attackingType, defendingType);
    }
    return multiplier;
  }

  /// Calculate defensive type effectiveness for a Pokémon with given types
  ///
  /// Returns a map of all attacking types to their effectiveness multipliers.
  /// Useful for displaying type weaknesses/resistances on Pokémon detail screens.
  ///
  /// Example:
  /// ```dart
  /// final weaknesses = typeChart.calculateDefensiveEffectiveness(['Water', 'Flying']);
  /// // Returns: {'Electric': 4.0, 'Rock': 2.0, 'Fighting': 0.5, 'Fire': 0.5, ...}
  /// ```
  Map<String, double> calculateDefensiveEffectiveness(
      List<String> defendingTypes) {
    if (_typeChart == null) {
      throw StateError('Type chart not loaded. Call loadTypeChart() first.');
    }

    final Map<String, double> effectiveness = {};

    // For each possible attacking type
    for (final attackingType in _typeChart!.keys) {
      double multiplier = 1.0;

      // Calculate combined effectiveness against all defending types
      for (final defendingType in defendingTypes) {
        multiplier *= getEffectiveness(attackingType, defendingType);
      }

      effectiveness[attackingType] = multiplier;
    }

    return effectiveness;
  }

  /// Convert effectiveness multiplier to human-readable string
  ///
  /// Returns:
  /// - "immune" for 0.0×
  /// - "quad-weak" or "4x weak" for 0.25×
  /// - "not-very-effective" or "resists" for 0.5×
  /// - null for 1.0× (neutral)
  /// - "super-effective" for 2.0×
  /// - "quad-super-effective" or "4x super" for 4.0×
  String? getEffectivenessString(double multiplier) {
    if (multiplier == 0.0) {
      return 'immune';
    } else if (multiplier <= 0.25) {
      return 'quad-weak';
    } else if (multiplier < 1.0) {
      return 'not-very-effective';
    } else if (multiplier == 1.0) {
      return null; // Neutral, no string needed
    } else if (multiplier == 2.0) {
      return 'super-effective';
    } else if (multiplier >= 4.0) {
      return 'quad-super-effective';
    }
    return null;
  }

  /// Get all Pokémon types supported by the type chart
  List<String> getAllTypes() {
    if (_typeChart == null) {
      throw StateError('Type chart not loaded. Call loadTypeChart() first.');
    }
    return _typeChart!.keys.toList();
  }

  /// Get metadata about the type chart (version, generation, source)
  Map<String, dynamic>? getMetadata() {
    return _metadata;
  }

  /// Clear cached data (useful for testing or hot reload)
  void clearCache() {
    _typeChart = null;
    _metadata = null;
  }
}
