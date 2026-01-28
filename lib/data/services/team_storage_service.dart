import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/team.dart';

class TeamStorageService {
  static const String _storageKey = 'championdex_teams';
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<Team>> loadTeams() async {
    await initialize();
    final jsonString = _prefs!.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => Team.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If there's an error parsing, return empty list
      return [];
    }
  }

  Future<void> saveTeams(List<Team> teams) async {
    await initialize();
    final jsonList = teams.map((team) => team.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await _prefs!.setString(_storageKey, jsonString);
  }

  Future<void> clearTeams() async {
    await initialize();
    await _prefs!.remove(_storageKey);
  }
}
