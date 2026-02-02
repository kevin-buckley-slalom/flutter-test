import 'dart:convert';
import 'package:flutter/services.dart';

class TypeChartDataService {
  static final TypeChartDataService _instance =
      TypeChartDataService._internal();
  Map<String, dynamic>? _typeChartCache;

  factory TypeChartDataService() {
    return _instance;
  }

  TypeChartDataService._internal();

  Future<void> loadData() async {
    if (_typeChartCache != null) return;

    try {
      final jsonString =
          await rootBundle.loadString('assets/data/type_chart.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      _typeChartCache = jsonData;
    } catch (e) {
      throw Exception('Failed to load type chart data: $e');
    }
  }

  /// Get all type names from the type chart
  List<String> getAllTypes() {
    final typeChart = _typeChartCache?['typeChart'];
    if (typeChart is Map) {
      return typeChart.keys.cast<String>().toList();
    }
    return [];
  }

  /// Get type effectiveness data
  Map<String, dynamic>? getTypeChart() {
    return _typeChartCache?['typeChart'];
  }

  bool isLoaded() => _typeChartCache != null;
}
