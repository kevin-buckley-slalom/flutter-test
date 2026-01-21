import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/move.dart';

class MoveDataService {
  static final MoveDataService _instance = MoveDataService._internal();
  Map<String, Move>? _moveCache;

  factory MoveDataService() {
    return _instance;
  }

  MoveDataService._internal();

  Future<void> loadData() async {
    if (_moveCache != null) return;

    try {
      final jsonString = await rootBundle.loadString('assets/data/moves.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      
      _moveCache = <String, Move>{};
      
      jsonData.forEach((moveName, moveJson) {
        if (moveJson is Map<String, dynamic>) {
          try {
            _moveCache![moveName] = Move.fromJson(moveJson);
          } catch (e) {
            // Skip malformed move entries
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to load moves data: $e');
    }
  }

  Move? getMoveByName(String moveName) {
    return _moveCache?[moveName];
  }

  List<Move> getAllMoves() {
    return _moveCache?.values.toList() ?? [];
  }

  bool isLoaded() => _moveCache != null;
}
