import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/nature.dart';

class NatureDataService {
  List<Nature>? _cachedNatures;

  Future<List<Nature>> loadNatures() async {
    if (_cachedNatures != null) {
      return _cachedNatures!;
    }

    final String jsonString =
        await rootBundle.loadString('assets/data/natures.json');
    final Map<String, dynamic> naturesMap = json.decode(jsonString);

    _cachedNatures = naturesMap.entries
        .map((entry) => Nature.fromJson(entry.key, entry.value))
        .toList();

    // Sort alphabetically
    _cachedNatures!.sort((a, b) => a.name.compareTo(b.name));

    return _cachedNatures!;
  }

  Nature? getNatureByName(String? name) {
    if (name == null || _cachedNatures == null) return null;
    try {
      return _cachedNatures!.firstWhere((nature) => nature.name == name);
    } catch (e) {
      return null;
    }
  }
}
